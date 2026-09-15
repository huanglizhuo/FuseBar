#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project FuseBar.xcodeproj -scheme FuseBar -configuration Debug -derivedDataPath build build
print "App: ${PWD}/build/Build/Products/Debug/FuseBar.app"
