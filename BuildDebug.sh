#!/bin/bash
#
# Build Disk Inventory Y (Swift version) for Debug
#

set -e

cd "$(dirname "$0")"

echo "Building Disk Inventory Y (Debug)..."

xcodebuild -project DiskInventoryY.xcodeproj \
           -scheme DiskInventoryY \
           -configuration Debug \
           -derivedDataPath build \
           build

echo ""
echo "Build complete!"
echo "App location: build/Build/Products/Debug/DiskInventoryY.app"
