import Foundation

/// `report --listen <run-id>...`: a self-contained page for judging the voices of several `speak`
/// runs blind. It plays each passage from every run under shuffled labels, collects a rating, the
/// passage's checks and a note for each reading, and saves them as JSON with the mapping from
/// label to run and voice, which the page reveals only after saving.
func listen(to runs: [String], in manifest: Manifest) throws {
  guard runs.count >= 2 else { throw BenchError("report --listen needs at least two runs to compare") }
  let sources = try runs.map(ListeningSource.init)
  let passages = manifest.samples.compactMap { sample -> Reading? in
    if case .reading(let reading) = sample { reading } else { nil }
  }
  var generator = SystemRandomNumberGenerator()
  let page = listeningPage(passages, runs: sources.map(\.run), hasAudio: { run, id in
    sources.first { $0.run.id == run.id }!.audio(id) != nil
  }, using: &generator)
  guard !page.isEmpty else { throw BenchError("These runs have no reading in common to compare.") }

  let directory = BenchData.directory.appending(path: "listening/\(utcStamp(Date()))", directoryHint: .isDirectory)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  for passage in page {
    for entry in passage.readings {
      let source = sources.first { $0.run.id == entry.run.id }!
      try FileManager.default.copyItem(at: source.audio(passage.id)!, to: directory.appending(path: entry.audio))
    }
  }
  let data = try JSONEncoder().encode(page)
  // A `</script>` inside the data must not end the page's script.
  let json = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
  try listeningHTML.replacingOccurrences(of: "__PASSAGES__", with: json)
    .write(to: directory.appending(path: "index.html"), atomically: true, encoding: .utf8)
  print(directory.appending(path: "index.html").path)
}

/// A voice and the run that read with it.
struct ListeningRun: Encodable {
  let id: String
  let provider: String
  let voice: String
}

struct ListeningPassage: Encodable {
  struct Entry: Encodable {
    /// The blind name the page shows, "A", "B" and so on.
    let label: String
    let run: ListeningRun
    /// The copied WAV, beside the page.
    let audio: String
  }

  let id: String
  let text: String
  let checks: [String]
  let readings: [Entry]
}

/// Each passage with a reading from every run that has one, labelled in a fresh random order per
/// passage so that a voice has no fixed name. Passages no run read are left out.
func listeningPage(
  _ passages: [Reading], runs: [ListeningRun], hasAudio: (ListeningRun, String) -> Bool,
  using generator: inout some RandomNumberGenerator
) -> [ListeningPassage] {
  passages.compactMap { passage in
    let shuffled = runs.filter { hasAudio($0, passage.id) }.shuffled(using: &generator)
    guard !shuffled.isEmpty else { return nil }
    let entries = shuffled.enumerated().map { index, run in
      let label = String(UnicodeScalar(UInt8(ascii: "A") + UInt8(index)))
      return ListeningPassage.Entry(label: label, run: run, audio: "\(passage.id)-\(label).wav")
    }
    return ListeningPassage(id: passage.id, text: passage.text, checks: passage.checks, readings: entries)
  }
}

/// A `speak` run's directory and what read it.
private struct ListeningSource {
  let run: ListeningRun
  private let directory: URL

  init(_ argument: String) throws {
    directory = runDirectory(argument)
    struct Info: Decodable {
      struct Speech: Decodable { let voice: String }
      let provider: String
      let speech: Speech?
    }
    let info = try? JSONDecoder().decode(Info.self, from: Data(contentsOf: directory.appending(path: "run.json")))
    guard let info, let speech = info.speech else { throw BenchError("\(argument) is not a speak run") }
    run = ListeningRun(id: directory.lastPathComponent, provider: info.provider, voice: speech.voice)
  }

  func audio(_ id: String) -> URL? {
    let url = directory.appending(path: "\(id).wav")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }
}

private let listeningHTML = #"""
  <!doctype html>
  <html lang="en">
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <title>EchoType listening</title>
  <style>
    body { font: 16px/1.5 system-ui, sans-serif; max-width: 46rem; margin: 2rem auto; padding: 0 1rem; }
    section { margin: 2.5rem 0; }
    h2 { font-size: 1rem; margin: 0; opacity: .6; font-weight: 500; }
    .text { font-size: 1.1rem; margin: .5rem 0 1rem; }
    .reading { border-top: 1px solid #8884; padding: .75rem 0; display: grid; gap: .5rem; }
    .reading > strong { font-size: .9rem; }
    audio { width: 100%; }
    label { margin-right: .75rem; white-space: nowrap; }
    .checks label { display: block; }
    textarea { width: 100%; font: inherit; box-sizing: border-box; }
    .reveal { display: none; opacity: .7; }
    .saved .reveal { display: inline; }
    button { font: inherit; padding: .5rem 1rem; }
  </style>
  <body>
  <main id="app"></main>
  <p><button id="save">Save ratings</button></p>
  <script>
  const passages = __PASSAGES__;
  const answers = [];
  const app = document.getElementById("app");

  function node(tag, props = {}, children = []) {
    const element = Object.assign(document.createElement(tag), props);
    element.append(...children);
    return element;
  }

  for (const passage of passages) {
    const section = node("section", {}, [
      node("h2", { textContent: passage.id }),
      node("p", { className: "text", textContent: passage.text }),
    ]);
    for (const reading of passage.readings) {
      const answer = { passage, reading, rating: null, checks: passage.checks.map(() => false), note: "" };
      answers.push(answer);
      const name = passage.id + "-" + reading.label;
      const rating = node("div", {}, [1, 2, 3, 4, 5].map(value => {
        const input = node("input", { type: "radio", name, value, onchange: () => { answer.rating = value; } });
        return node("label", {}, [input, " " + value]);
      }));
      const checks = node("div", { className: "checks" }, passage.checks.map((check, index) =>
        node("label", {}, [
          node("input", { type: "checkbox", onchange: event => { answer.checks[index] = event.target.checked; } }),
          " " + check + " right",
        ])));
      section.append(node("div", { className: "reading" }, [
        node("strong", {}, ["Reading " + reading.label, node("span", {
          className: "reveal", textContent: "  (" + reading.run.provider + ", " + reading.run.voice + ", " + reading.run.id + ")",
        })]),
        node("audio", { controls: true, preload: "none", src: reading.audio }),
        rating,
        checks,
        node("textarea", { rows: 2, placeholder: "Notes", oninput: event => { answer.note = event.target.value; } }),
      ]));
    }
    app.append(section);
  }

  document.getElementById("save").onclick = () => {
    const ratings = answers.map(({ passage, reading, rating, checks, note }) => ({
      passage: passage.id,
      label: reading.label,
      run: reading.run.id,
      provider: reading.run.provider,
      voice: reading.run.voice,
      rating,
      checks: passage.checks.map((check, index) => ({ check, right: checks[index] })),
      note,
    }));
    const blob = new Blob([JSON.stringify({ savedAt: new Date().toISOString(), ratings }, null, 2)], { type: "application/json" });
    const link = node("a", { href: URL.createObjectURL(blob), download: "ratings.json" });
    link.click();
    document.body.classList.add("saved");
  };
  </script>
  """#
