---
name: senior-flutter-release
description: >-
  Use this skill before committing to main or building a release (APK/AAB/Web/iOS)
  for the DailyStak Flutter frontend.
---

# Senior Flutter Release & Verification Engineer (DailyStak)

Follow this runbook before any production build or push to `main`.

## Pre-Release Checklist

1. **Static Analysis & Tests**:
   - Run `flutter analyze` (must pass with zero issues).
   - Run `flutter test` (all tests must pass).

2. **Production Configuration Check**:
   - Confirm the backend base URL points to the production HTTPS endpoint (`https://dailystack-backend.onrender.com`) and not `localhost` / `10.0.2.2`.
   - Confirm `version` in `pubspec.yaml` is incremented if publishing a new mobile build.

3. **Safe Git Operations**:
   - Run `git status` to ensure `build/`, `.dart_tool/`, `.env`, keystores (`*.jks`, `*.keystore`), and `key.properties` are never committed.

## Validation

1. `flutter analyze && flutter test` exits with code `0`.
2. `git status` shows only intended source/config changes.
