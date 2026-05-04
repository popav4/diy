#!/bin/bash
#
# Build Disk Inventory Y (Swift version) for Debug
#

set -e

cd "$(dirname "$0")"

LOG_DIR="${LOG_DIR:-.tmp/log/build}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/BuildDebug.log"

exec > >(tee "$LOG_FILE") 2>&1

echo "Building Disk Inventory Y (Debug)..."
echo "Log file: $LOG_FILE"

xcodebuild -project DiskInventoryY.xcodeproj \
           -scheme DiskInventoryY \
           -configuration Debug \
           -derivedDataPath build \
           clean build

echo ""
echo "Build complete!"
echo "App location: build/Build/Products/Debug/Disk Inventory Y.app"
echo "Log file: $LOG_FILE"
