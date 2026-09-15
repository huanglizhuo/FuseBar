#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project MergeBar.xcodeproj -scheme MergeBar -configuration Debug -derivedDataPath build -destination 'platform=macOS' test
