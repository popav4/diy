#!/bin/bash
#
# Build Disk Inventory Y (Swift version) for Release
#

set -e

cd "$(dirname "$0")"

LOG_DIR="${LOG_DIR:-.tmp/log/build}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/BuildRelease.log"

exec > >(tee "$LOG_FILE") 2>&1

echo "Building Disk Inventory Y (Swift)..."
echo "Log file: $LOG_FILE"

xcodebuild -project DiskInventoryY.xcodeproj \
           -scheme DiskInventoryY \
           -configuration Release \
           -derivedDataPath build \
           CODE_SIGN_IDENTITY="-" \
           CODE_SIGNING_REQUIRED=NO \
           clean build

# Re-sign the app
codesign --force --sign - "build/Build/Products/Release/Disk Inventory Y.app"

echo ""
echo "Build complete!"
echo "App location: build/Build/Products/Release/Disk Inventory Y.app"

# Verify architecture
echo ""
echo "Architecture:"
lipo -info "build/Build/Products/Release/Disk Inventory Y.app/Contents/MacOS/Disk Inventory Y"
echo "Log file: $LOG_FILE"
