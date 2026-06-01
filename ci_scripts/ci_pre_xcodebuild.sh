#!/bin/sh
set -eu

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/..}"
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi
