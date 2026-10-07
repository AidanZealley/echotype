import Foundation

/// The exact files one model needs, pinned so a download is reproducible and verifiable.
struct ModelManifest: Sendable, Equatable {
  struct File: Sendable, Equatable {
    /// Relative to the repository root, and to the model's directory once installed.
    let path: String
    let size: Int64
    /// Lowercase hex.
    let sha256: String
  }

  let name: String
  /// The Hugging Face repository, such as `owner/model`.
  let repository: String
  /// The full commit hash, never a branch, so the files cannot change underneath the hashes.
  let revision: String
  let license: String
  let files: [File]

  var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }

  /// Names the model's directory. Includes the revision, so a new revision never reuses files.
  var directoryName: String { "\(name)-\(revision)" }

  func downloadURL(for file: File) -> URL {
    URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(file.path)")!
  }
}
