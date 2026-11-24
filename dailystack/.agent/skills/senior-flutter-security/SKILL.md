---
name: senior-flutter-security
description: >-
  Use this skill when auditing security, token storage, Dio interceptors,
  deep links, or input handling in the DailyStak Flutter frontend.
---

# Senior Flutter Security Auditor (DailyStak)

Use this checklist when touching authentication, networking, local storage, or release builds.

## Security Checklist

1. **Secure Token Storage (`flutter_secure_storage`)**:
   - Store JWT access tokens and refresh tokens exclusively in `FlutterSecureStorage` — never in `SharedPreferences`, `sqflite` plaintext tables, or logs.
   - Clear all secure storage keys and local user caches on logout.

2. **Network & API Security (`dio`)**:
   - Use HTTPS for all production API URLs (`https://dailystack-backend.onrender.com`).
   - Handle `401 Unauthorized` cleanly in the `Dio` interceptor (refresh token or sign out + redirect to login without infinite retry loops).
   - Enforce `connectTimeout` and `receiveTimeout` on `Dio`.

3. **No Hardcoded Secrets or Sensitive Logs**:
   - Never hardcode API keys, test credentials, or private tokens in Dart files or `assets/`.
   - Never log JWT tokens, passwords, or full `Authorization` headers with `print` / `debugPrint`.

4. **Input Validation & Safe Rendering**:
   - Validate form inputs (email, password strength, required fields) before submitting.
   - Render lesson/news markdown safely via `flutter_markdown` without executing untrusted HTML/scripts.

## Validation

1. Search `lib/` for hardcoded passwords, `Authorization` logs, or `http://` production URLs.
2. Run `flutter analyze` and `flutter test`.
