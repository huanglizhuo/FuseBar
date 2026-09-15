#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project MergeBar.xcodeproj -scheme MergeBar -configuration Debug -derivedDataPath build build
print "App: ${PWD}/build/Build/Products/Debug/MergeBar.app"
