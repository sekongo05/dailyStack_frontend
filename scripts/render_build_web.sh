#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"
if [ ! -d "${FLUTTER_DIR}" ]; then
  echo "Installing Flutter SDK (stable)..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
cd dailystack
flutter pub get
flutter build web --release
