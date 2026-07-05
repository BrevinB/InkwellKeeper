#!/bin/sh

# Xcode Cloud post-clone hook.
# Runs after the repository is cloned, before dependency resolution / build.
# Installs SwiftLint and lints the project; a non-zero exit fails the build.
#
# Docs: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts

set -e

echo "[ci_post_clone] Installing SwiftLint via Homebrew..."
brew install swiftlint

echo "[ci_post_clone] Running SwiftLint..."
cd "$CI_PRIMARY_REPOSITORY_PATH"
# --baseline suppresses pre-existing violations (swiftlint-baseline.json) so the
# build only fails on NEW violations introduced by a change. Regenerate the
# baseline after a deliberate cleanup with: swiftlint lint --write-baseline swiftlint-baseline.json
swiftlint lint --strict --config .swiftlint.yml --baseline swiftlint-baseline.json

echo "[ci_post_clone] SwiftLint passed."
