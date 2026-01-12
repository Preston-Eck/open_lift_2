#!/bin/bash
set -e

echo "🚀 Starting Flutter web build for Netlify..."

# Install Flutter
echo "📦 Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
echo "✅ Verifying Flutter installation..."
flutter --version

# Enable web support
echo "🌐 Enabling Flutter web support..."
flutter config --enable-web

# Get dependencies
echo "📚 Getting Flutter dependencies..."
flutter pub get

# Build for web
echo "🔨 Building Flutter web app..."
flutter build web --release

echo "✨ Build complete! Output in build/web"
