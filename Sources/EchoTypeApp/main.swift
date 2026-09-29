// `--mcp` has to take effect before SwiftUI starts, so the app's entry point is here
// instead of an `@main` attribute.
if CommandLine.arguments.contains("--mcp") {
  MCPProcess.run()
} else {
  EchoTypeApp.main()
}
