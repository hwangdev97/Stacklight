#!/bin/sh
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen..."
  brew install xcodegen
fi

echo "Generating Xcode project from project.yml..."
xcodegen generate

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi
