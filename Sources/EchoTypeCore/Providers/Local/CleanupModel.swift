import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Tokenizers

/// A loaded cleanup model, shared by every candidate. It sends `Reviser`'s prompt and window
/// unchanged and returns the reply as plain text, with greedy sampling.
///
/// The fixed prompt is the start of every request, so its key-value cache is built once and
/// each request copies it, then prefills only the window. Nothing else carries between requests.
final class CleanupModel: Sendable {
  /// The prompt's tokens and their cache. The cache is mutable, so it is touched only inside
  /// `container.perform`, which runs one closure at a time.
  private final class PromptCache: @unchecked Sendable {
    let tokens: [Int]
    let cache: [KVCache]

    init(tokens: [Int], cache: [KVCache]) {
      self.tokens = tokens
      self.cache = cache
    }
  }

  /// The longest prompt forward pass between cancellation checks while prefilling a window.
  private static let prefillStep = 128
  /// Cached buffers beyond this are freed, so they do not inflate the process footprint.
  private static let bufferCacheLimit = 64 * 1024 * 1024

  private let container: ModelContainer
  private let prompt: PromptCache
  private let templateContext: [String: any Sendable]

  private init(container: ModelContainer, prompt: PromptCache, templateContext: [String: any Sendable]) {
    self.container = container
    self.prompt = prompt
    self.templateContext = templateContext
  }

  /// Loads the weights, prefills the prompt and runs one short request, so the first real one
  /// does not pay for compiling kernels.
  static func load(from directory: URL, templateContext: [String: any Sendable]) async throws -> CleanupModel {
    Memory.cacheLimit = bufferCacheLimit
    let container = try await LLMModelFactory.shared.loadContainer(from: directory, using: TokenizerLoader())
    let prompt = try await container.perform { context in
      try prefill(Reviser.prompt, context: context, templateContext: templateContext)
    }
    let model = CleanupModel(container: container, prompt: prompt, templateContext: templateContext)
    _ = try await model.revise(
      CleanupRequest(
        prompt: Reviser.prompt, text: "Let's meet on Tuesday, no, Wednesday.", final: false,
        credential: nil))
    return model
  }

  func revise(_ request: CleanupRequest) async throws -> String {
    try await container.perform { [self] context in try await generate(request, context: context) }
  }

  /// The reply is cut off at `outputLimit`, and a cut-off reply is an error rather than a
  /// shortened one: `Reviser` accepts any in-order subset of the window, so it would insert
  /// text that silently lost its end.
  private func generate(_ request: CleanupRequest, context: ModelContext) async throws -> String {
    try Task.checkCancellation()
    let tokens = try Self.template(request.prompt, request.text, context, templateContext)
    let windowTokens = context.tokenizer.encode(text: request.text, addSpecialTokens: false).count
    let parameters = GenerateParameters(
      maxTokens: Self.outputLimit(windowTokens: windowTokens),
      temperature: 0,
      prefill: PrefillParameters(stepSize: Self.prefillStep))

    // A request that does not start with the prompt, such as a template that names today's
    // date after midnight, prefills everything.
    let reuse = tokens.starts(with: prompt.tokens)
    let cache = reuse ? prompt.cache.map { $0.copy() } : try context.model.newCache(parameters: parameters)
    let rest = reuse ? Array(tokens.dropFirst(prompt.tokens.count)) : tokens

    // Prefill happens here and checks for cancellation between chunks.
    let iterator = try TokenIterator(
      input: LMInput(tokens: MLXArray(rest)), model: context.model, cache: cache, parameters: parameters)
    let (stream, task) = generateTask(
      promptTokenCount: tokens.count, modelConfiguration: context.configuration,
      tokenizer: context.tokenizer, iterator: iterator)

    var reply = ""
    var stopReason: GenerateStopReason?
    await withTaskCancellationHandler {
      for await generation in stream {
        switch generation {
        case .chunk(let text): reply += text
        case .info(let info): stopReason = info.stopReason
        case .toolCall, .rejectedToolCall: break
        }
      }
      await task.value
    } onCancel: {
      task.cancel()
    }
    try Task.checkCancellation()
    if stopReason == .length { throw ProviderError.failed("The cleanup reply ran past its length limit") }
    return reply
  }

  /// A cleanup reply is about as long as its window: it deletes words and fixes punctuation. The
  /// margin covers punctuation and capitals that tokenise differently.
  static func outputLimit(windowTokens: Int) -> Int {
    windowTokens + windowTokens / 4 + 16
  }

  private static func template(
    _ system: String, _ user: String, _ context: ModelContext, _ templateContext: [String: any Sendable]
  ) throws -> [Int] {
    try context.tokenizer.applyChatTemplate(
      messages: [["role": "system", "content": system], ["role": "user", "content": user]],
      tools: nil, additionalContext: templateContext)
  }

  /// Runs the tokens every request starts with through the model. Two different windows show
  /// where they end: the template's text before the window is the same for both.
  private static func prefill(
    _ system: String, context: ModelContext, templateContext: [String: any Sendable]
  ) throws -> PromptCache {
    let first = try template(system, "a", context, templateContext)
    let second = try template(system, "b", context, templateContext)
    let shared = zip(first, second).prefix { $0 == $1 }.map(\.0)
    let cache = try context.model.newCache(parameters: nil)
    _ = context.model(LMInput.Text(tokens: MLXArray(shared)[.newAxis]), cache: cache, state: nil)
    eval(cache)
    return PromptCache(tokens: shared, cache: cache)
  }
}

/// Loads swift-transformers' tokenizer, which supplies encoding and the Jinja chat template.
private struct TokenizerLoader: MLXLMCommon.TokenizerLoader {
  func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
    Bridge(try await AutoTokenizer.from(modelFolder: directory))
  }

  /// MLX Swift LM's tokenizer contract over swift-transformers'. The names differ slightly.
  private struct Bridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) { self.upstream = upstream }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
      upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
      upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }
    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
      messages: [[String: any Sendable]], tools: [[String: any Sendable]]?,
      additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
      do {
        return try upstream.applyChatTemplate(
          messages: messages, tools: tools, additionalContext: additionalContext)
      } catch Tokenizers.TokenizerError.missingChatTemplate {
        throw MLXLMCommon.TokenizerError.missingChatTemplate
      }
    }
  }
}
