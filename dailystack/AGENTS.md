# DailyStak Frontend (Flutter) — Team & Agent Rules

These rules apply automatically to every agent (solo or `/teamwork` swarm) working in `/Users/macbookairm1/Desktop/DailyStaskFrontend/dailystack`.

## Autonomous Execution (No Unnecessary Confirmation)
- Proceed autonomously from design through implementation, `flutter analyze`, `flutter test`, and commit/push on `develop` **without** asking the user for permission at intermediate steps.
- Resolve analyzer warnings, widget/unit test failures, or model mismatches directly instead of stopping to ask.
- Only ask the user if an action targets `main` (production release) or hits a real UX/product ambiguity not covered by `Cahier_des_charges_DailyStack_V3.md` or `API_INTEGRATION_FRONTEND.md`.

## Git & Branch Discipline
- Always work, commit, and push on the `develop` branch (`git-commit-push-dev`).
- **Never** push directly to `main` unless the user explicitly asks for a production release (`senior-flutter-release`).
- Never stage or commit `.env`, keystores (`*.jks`, `*.keystore`), `key.properties`, `build/`, or `.dart_tool/`.

## `/teamwork` & Parallel Full-Stack Rules
- When a task touches both Backend and Frontend, follow `dailystak-fullstack-parallel`:
  1. **Contract first**: read/confirm the API contract in `/Users/macbookairm1/Desktop/DailyStak/API_INTEGRATION_FRONTEND.md` before implementing models, Dio repositories, and Riverpod providers.
  2. **Frontend track**: follow `dailystak-flutter-workflow` (`senior-flutter-architect`, `senior-dart-clean-code`, `senior-flutter-testing`, `senior-flutter-security`).
  3. **Cross-stack QA**: verify Flutter JSON models and endpoints match the backend DTOs, and run `/Users/macbookairm1/Desktop/DailyStak/.agent/skills/dailystak-fullstack-parallel/scripts/verify-all.sh` when both repos are modified.

## Required Verification Gate
- Run `.agent/skills/dailystak-flutter-workflow/scripts/verify.sh` (`flutter analyze && flutter test`) after the final edit and before committing.
- Never claim checks pass without observing zero analyzer issues and passing tests after the last edit.
