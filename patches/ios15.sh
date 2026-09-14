#!/bin/bash
# iOS 15 compatibility patches for OpenMinis.
# Runs from the root of the cloned upstream repo.
set -eo pipefail

PBX=src/ios/Minis.xcodeproj/project.pbxproj

echo "==> lowering all iOS deployment targets to 15.0"
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$PBX"
echo "    targets at 15.0: $(grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' "$PBX")"

# The project ships only a template; BUILDING.md says to copy it before building.
echo "==> creating ProviderCustomization.xcconfig from template"
cp src/ios/Configs/ProviderCustomization.xcconfig.example \
   src/ios/Configs/ProviderCustomization.xcconfig

# rclone's XCFramework is built with min OS 16.0, which would clash with our
# 15.0 deployment target at link time. Relax it to match.
echo "==> relaxing rclone minimum OS from 16.0 to 15.0"
sed -i '' 's/-miphoneos-version-min=16\.0/-miphoneos-version-min=15.0/g; s/-mios-simulator-version-min=16\.0/-mios-simulator-version-min=15.0/g' deps/build_rclone_ios.sh

# The FileProvider extension uses NSFileProviderReplicatedExtension APIs that
# landed in iOS 16 (NSFileProviderRequest, NSFileProviderItemVersion/Fields,
# trashContainer). Their iOS 15 predecessors may no longer exist in the iOS 26
# SDK, so this one extension stays on 16.0 while the app installs on iOS 15.
echo "==> raising MinisFileProvider extension to 16.0"
python3 set_deployment.py "$PBX" MinisFileProvider 16.0

echo "==> patch script complete"
