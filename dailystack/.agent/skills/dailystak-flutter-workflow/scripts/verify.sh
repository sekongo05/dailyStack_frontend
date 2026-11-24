#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking staged files for secrets (.env / keystores)..."
if git diff --cached --name-only | grep -qE '(^|/)\.env$|\.jks$|\.keystore$|key\.properties$'; then
  echo "ERROR: Sensitive file staged for commit! Unstage it with git reset HEAD <file>"
  exit 1
fi

echo "==> Running flutter analyze..."
flutter analyze

echo "==> Running flutter test..."
flutter test

echo "==> Git status (branch: $(git branch --show-current)):"
git status -s
