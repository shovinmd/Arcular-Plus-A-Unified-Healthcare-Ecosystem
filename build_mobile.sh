#!/bin/bash

echo "Building Mobile Version of Arcular+..."

# Build for Android
flutter build apk --release

echo "Mobile build completed!"
echo "APK file is in build/app/outputs/flutter-apk/app-release.apk" 