#!/usr/bin/env bash
# Run this script in your terminal (NOT via Claude Code) to configure Firebase.
# Prerequisites: firebase login, flutterfire_cli, Flutter SDK on PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIVARA_DIR="$SCRIPT_DIR/../nivara"

export PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$HOME/.npm-global/bin:$PATH"

echo "==> Checking tools..."
command -v firebase  >/dev/null || { echo "ERROR: firebase CLI not found. Run: npm install -g firebase-tools --prefix ~/.npm-global"; exit 1; }
command -v flutterfire >/dev/null || { echo "ERROR: flutterfire not found. Run: dart pub global activate flutterfire_cli"; exit 1; }
command -v flutter   >/dev/null || { echo "ERROR: flutter not found. Add Flutter to PATH."; exit 1; }

echo "==> Firebase projects:"
firebase projects:list

echo ""
read -r -p "Enter your Firebase project ID (e.g. nivara-app-12345): " PROJECT_ID

echo "==> Running flutterfire configure for project: $PROJECT_ID"
cd "$NIVARA_DIR"
flutterfire configure \
  --project="$PROJECT_ID" \
  --platforms=android,ios \
  --yes

echo ""
echo "==> Done! Firebase config files generated:"
echo "    nivara/lib/firebase_options.dart"
echo "    nivara/android/app/google-services.json"
echo "    nivara/ios/Runner/GoogleService-Info.plist"
echo ""
echo "Next steps in the Firebase Console (console.firebase.google.com):"
echo "  1. Authentication → Sign-in method → Enable Google + Email/Password"
echo "  2. Firestore Database → Create database → Production mode → us-central1"
echo "  3. Storage → Get started → us-central1"
