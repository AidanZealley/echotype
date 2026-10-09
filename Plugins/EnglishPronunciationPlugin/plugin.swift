import Foundation
import PackagePlugin

@main
struct EnglishPronunciationPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let dependency = context.package.dependencies.first(where: { $0.package.id == "espeak-ng-spm" }) else {
      throw BuildError.missingDependency
    }
    let source = dependency.package.directoryURL.appending(path: "Sources/data")
    let output = context.pluginWorkDirectoryURL.appending(path: "EnglishPronunciation.bundle")
    let inputs = try ["espeak-ng-data", "phsource", "dictsource"].flatMap { name -> [URL] in
      let directory = source.appending(path: name).resolvingSymlinksInPath()
      return try FileManager.default.subpathsOfDirectory(atPath: directory.path)
        .map { directory.appending(path: $0) }
        .filter { var isDirectory: ObjCBool = false
          return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
    } + [dependency.package.directoryURL.appending(path: "LICENSE")]
    return [.buildCommand(
      displayName: "Compile pinned eSpeak NG English pronunciation data",
      executable: try context.tool(named: "EnglishPronunciationBuilder").url,
      arguments: [source.path, output.path],
      inputFiles: inputs,
      outputFiles: [output])]
  }
  enum BuildError: Error { case missingDependency }
}
