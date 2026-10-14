#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

# The Swift 6.1 toolchain cannot read the macOS 27 SDK, and that SDK declares SwiftUI property
# wrappers as macros whose plugin only ships with Xcode. Use the Command Line Tools compiler with the macOS 26 SDK.
export PATH="/usr/bin:${PATH}"
export SDKROOT="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk}"

swift build -c release "$@"

application="${root}/build/Soundboard.app"
rm -rf "${application}"
mkdir -p "${application}/Contents/MacOS"
cp "$(swift build -c release "$@" --show-bin-path)/Soundboard" "${application}/Contents/MacOS/Soundboard"
cp "${root}/Support/Info.plist" "${application}/Contents/Info.plist"

codesign --force --sign - "${application}"
echo "Built ${application}"
