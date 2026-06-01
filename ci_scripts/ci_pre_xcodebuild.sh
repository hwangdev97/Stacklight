#!/bin/sh
set -eu

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
fi
