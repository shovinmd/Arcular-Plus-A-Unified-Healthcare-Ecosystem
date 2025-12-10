#!/bin/bash

echo "Building Web Version of Arcular+..."

# Build for web
flutter build web --release

echo "Web build completed!"
echo "Files are in build/web/"
echo "You can deploy these files to any web hosting service." 