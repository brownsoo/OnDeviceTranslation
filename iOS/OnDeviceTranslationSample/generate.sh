#!/bin/sh
# Regenerates the Xcode project and re-integrates CocoaPods. Run after adding or removing files.
set -e
export LANG=en_US.UTF-8
cd "$(dirname "$0")"
xcodegen generate
pod install
