#!/usr/bin/env bash
# Builds, signs and (re)launches the development bundle at .build/EchoType.app.
# Arguments are passed to the app, for example `./scripts/run.sh --hud-demo`.
set -euo pipefail

exec "$(dirname "$0")/deploy.sh" debug .build/EchoType.app "$@"
