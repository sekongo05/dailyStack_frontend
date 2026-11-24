---
name: senior-flutter-testing
description: >-
  Use this skill when writing or updating unit tests, Riverpod provider tests,
  or widget tests in the DailyStak Flutter frontend.
---

# Senior Flutter Testing & QA Engineer (DailyStak)

Follow these practices when adding features, fixing bugs, or verifying regressions in `dailystack`.

## Testing Standards

1. **Regression Test for Every Bug Fix**:
   - Add a unit or widget test in `test/` covering the bug scenario (parsing edge case, offline fallback, auth redirect, or UI state).

2. **Provider & Repository Unit Tests**:
   - Test `flutter_riverpod` notifiers using `ProviderContainer` with overridden repository/Dio mocks (no live network calls).
   - Verify loading, data, and error states as well as `401` / offline behavior.

3. **Widget Tests**:
   - Pump widgets wrapped in `ProviderScope` with mocked dependencies and assert key UI states, validation messages, and user interactions.

4. **Strict Verification**:
   - Always run `flutter analyze` and `flutter test` after the final edit.

## Validation

1. Confirm `flutter analyze` reports zero issues.
2. Confirm `flutter test` passes with all tests green.
