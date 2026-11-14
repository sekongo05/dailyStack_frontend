#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"
if [ ! -d "${FLUTTER_DIR}" ]; then
  echo "Installing Flutter SDK (stable)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

git config --global --add safe.directory "${FLUTTER_DIR}" || true
export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --no-analytics --enable-web >/dev/null 2>&1 || true
flutter --version
cd dailystack
flutter pub get
flutter build web --release
