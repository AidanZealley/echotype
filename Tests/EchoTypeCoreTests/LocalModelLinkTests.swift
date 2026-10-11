import Foundation
import Testing

@testable import EchoTypeCore

@Suite struct LocalModelLinkTests {
  @Test("Fixed cache paths preserve foreign folders and relative links", arguments: ["folder", "valid", "dangling", "nearby-store", "unknown-model"])
  func foreignPaths(kind: String) throws {
    let files = FileManager.default
    let fixture = files.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? files.removeItem(at: fixture) }
    let store = fixture.appending(path: "Models")
    let destination = store.appending(path: "parakeet-ctc-110m-" + String(repeating: "a", count: 40))
    let link = fixture.appending(path: "cache/model")
    try files.createDirectory(at: destination, withIntermediateDirectories: true)
    try files.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    if kind == "folder" {
      try files.createDirectory(at: link, withIntermediateDirectories: true)
      try Data("preserve".utf8).write(to: link.appending(path: "sentinel"))
    } else {
      let relative = kind == "nearby-store"
        ? "../Models-other/parakeet-ctc-110m-" + String(repeating: "b", count: 40)
        : kind == "unknown-model" ? "../Models/foreign-model" : "../foreign/model"
      if kind != "dangling" {
        try files.createDirectory(at: URL(fileURLWithPath: relative, relativeTo: link.deletingLastPathComponent()), withIntermediateDirectories: true)
      }
      try files.createSymbolicLink(atPath: link.path, withDestinationPath: relative)
    }
    let original = try? files.destinationOfSymbolicLink(atPath: link.path)
    try linkFolder(at: link, to: destination, modelName: "parakeet-ctc-110m", ownedRoot: store)
    #expect(link.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL)
    if kind == "folder" {
      #expect(try Data(contentsOf: link.appending(path: "sentinel")) == Data("preserve".utf8))
    } else {
      #expect(try files.destinationOfSymbolicLink(atPath: link.path) == original)
    }
  }

  @Test("Owned old revisions may be replaced and equivalent relative targets remain intact")
  func ownedRevision() throws {
    let files = FileManager.default
    let fixture = files.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? files.removeItem(at: fixture) }
    let store = fixture.appending(path: "Models")
    let name = ParakeetManifests.keywordSpotting.name
    let previous = name + "-" + String(repeating: "b", count: 40)
    let current = name + "-" + String(repeating: "a", count: 40)
    let destination = store.appending(path: current)
    let link = fixture.appending(path: "cache/model")
    try files.createDirectory(at: destination, withIntermediateDirectories: true)
    try files.createDirectory(at: store.appending(path: previous), withIntermediateDirectories: true)
    try files.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    try files.createSymbolicLink(atPath: link.path, withDestinationPath: "../Models/" + previous)
    try linkFolder(at: link, to: destination, modelName: name, ownedRoot: store)
    #expect(link.resolvingSymlinksInPath().standardizedFileURL == destination.resolvingSymlinksInPath().standardizedFileURL)
    #expect(files.fileExists(atPath: store.appending(path: previous).path))
    try files.removeItem(at: link)
    let relative = "../Models/" + current
    try files.createSymbolicLink(atPath: link.path, withDestinationPath: relative)
    try linkFolder(at: link, to: destination, modelName: name, ownedRoot: store)
    #expect(try files.destinationOfSymbolicLink(atPath: link.path) == relative)
  }
}
