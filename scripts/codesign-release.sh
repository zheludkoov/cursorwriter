#!/usr/bin/env bash
# Reproducibly code-sign the SwiftPM release (or debug) executable with App Sandbox entitlements.
#
# Usage:
#   ./scripts/codesign-release.sh
#   CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/codesign-release.sh
#
# Defaults to ad-hoc signing (`-`) so local sandbox verification works without an Apple Developer cert.
# For notarized / Developer ID distribution, set CODESIGN_IDENTITY to your "Developer ID Application" identity.
#
# Xcode: open this package, select the TranslateHotkey scheme, then set Build Settings >
# "Code Signing Entitlements" to TranslateHotkey.entitlements (package root) so archives match this script.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENTITLEMENTS="${ROOT}/TranslateHotkey.entitlements"
CONFIGURATION="${CONFIGURATION:-release}"
IDENTITY="${CODESIGN_IDENTITY:--}"

if [[ ! -f "$ENTITLEMENTS" ]]; then
	echo "error: missing $ENTITLEMENTS" >&2
	exit 1
fi

swift build -c "$CONFIGURATION"
BIN="$(swift build -c "$CONFIGURATION" --show-bin-path)/TranslateHotkey"

if [[ ! -f "$BIN" ]]; then
	echo "error: expected binary at $BIN" >&2
	exit 1
fi

echo "Signing: $BIN"
echo "Identity: $IDENTITY"

codesign --force --sign "$IDENTITY" \
	--entitlements "$ENTITLEMENTS" \
	--options runtime \
	"$BIN"

codesign --verify --verbose=2 "$BIN"
echo "OK (sandbox entitlements embedded)."
