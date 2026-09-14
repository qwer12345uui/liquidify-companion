#!/bin/bash
# iOS 15 compatibility patches for OpenMinis.
set -eo pipefail

PBX=src/ios/Minis.xcodeproj/project.pbxproj

echo "==> lowering all iOS deployment targets to 15.0"
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$PBX"

echo "    targets now at 15.0: $(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' "$PBX")"
echo "==> patch script complete"
