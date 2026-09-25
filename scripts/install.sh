#!/usr/bin/env bash
# Builds EchoType in release mode, replaces /Applications/EchoType.app with it and
# launches the installed copy.
set -euo pipefail

exec "$(dirname "$0")/deploy.sh" release /Applications/EchoType.app
