#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

scripts/build-app.sh

application="${root}/build/Soundboard.app"
version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${application}/Contents/Info.plist")"
archive="${root}/build/Soundboard-${version}.zip"

# ditto keeps the code signature and extended attributes that zip would drop.
rm -f "${archive}"
ditto -c -k --keepParent "${application}" "${archive}"
echo "Packaged ${archive}"
