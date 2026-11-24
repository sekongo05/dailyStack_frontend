---
name: dailystak-flutter-workflow
description: >-
  End-to-end development workflow for the DailyStak Flutter frontend. Use this
  skill when building a feature, fixing a bug, or preparing a change from
  architecture through tests, security check, and push to develop or main.
---

# DailyStak Flutter End-to-End Development Workflow

Follow these stages in order for any non-trivial change in `dailystack`.

## Stage 1: Design & Architecture
- Activate `senior-flutter-architect` to plan feature-first structure, Riverpod providers, GoRouter routes, and Dio/sqflite offline sync.

## Stage 2: Implementation & Clean Code
- Implement using `senior-dart-clean-code` (`const` widgets, small composable classes, `context.mounted` guards, zero lints).

## Stage 3: Testing & Security Audit
- Activate `senior-flutter-testing` to add/update unit and widget tests.
- Activate `senior-flutter-security` to verify `FlutterSecureStorage`, HTTPS endpoints, and safe error handling.
- Run the verification script:
  [verify.sh](./scripts/verify.sh)

## Stage 4: Commit & Push
- For regular development work: follow `git-commit-push-dev` to commit and push to `develop`.
- For release builds / production: follow `senior-flutter-release` before pushing to `main`.
