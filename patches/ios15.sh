#!/bin/bash
# iOS deployment-target patches for OpenMinis.
# Usage: ios15.sh [version]    (default 15.0)
#
# The app was written against iOS 26.2. Lowering it exposes availability
# errors; this script also handles the few non-pbxproj prerequisites.
set -eo pipefail

TARGET="${1:-15.0}"
PBX=src/ios/Minis.xcodeproj/project.pbxproj

echo "==> setting all iOS deployment targets to $TARGET"
sed -i '' "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = $TARGET;/g" "$PBX"
echo "    targets at $TARGET: $(grep -c "IPHONEOS_DEPLOYMENT_TARGET = $TARGET;" "$PBX")"

# The project ships only a template; BUILDING.md says to copy it before building.
echo "==> creating ProviderCustomization.xcconfig from template"
cp src/ios/Configs/ProviderCustomization.xcconfig.example \
   src/ios/Configs/ProviderCustomization.xcconfig

# rclone's XCFramework is built with min OS 16.0, which would clash with a
# lower deployment target at link time. Relax it to match.
echo "==> relaxing rclone minimum OS to $TARGET"
sed -i '' 's/-miphoneos-version-min=16\.0/-miphoneos-version-min='"$TARGET"'/g; s/-mios-simulator-version-min=16\.0/-mios-simulator-version-min='"$TARGET"'/g' deps/build_rclone_ios.sh

# FileProvider needs iOS 16 APIs (NSFileProviderRequest,
# NSFileProviderItemVersion/Fields, trashContainer), so keep this extension at
# 16.0 even when the app itself goes lower.
echo "==> ensuring MinisFileProvider extension is at 16.0"
python3 set_deployment.py "$PBX" MinisFileProvider 16.0

echo "==> patch script complete"
