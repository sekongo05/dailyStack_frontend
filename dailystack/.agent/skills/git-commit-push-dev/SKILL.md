---
name: git-commit-push-dev
description: >-
  Use this skill when committing and pushing changes to the development branch
  (develop) in the DailyStak Flutter frontend, ensuring flutter analyze and
  flutter test pass and secrets are excluded.
---

# Git Commit & Push to Development Branch (DailyStak Flutter)

Follow this workflow whenever committing and pushing frontend changes to `develop`.

## Steps

1. **Verify Analysis & Tests (when Dart or pubspec files changed)**:
   - Run `flutter analyze` and `flutter test` and confirm both pass cleanly.

2. **Inspect Working Tree & Exclude Secrets**:
   - Run `git status`.
   - Never stage `.env`, keystores (`*.jks`, `*.keystore`), `key.properties`, `build/`, or `.dart_tool/`.

3. **Ensure You Are on the `develop` Branch**:
   - Check branches: `git branch -a`.
   - If `develop` exists locally, switch to it (`git checkout develop`).
   - If `develop` does not exist yet, create it (`git checkout -b develop`).

4. **Stage, Commit & Push**:
   - Stage intended files explicitly (`git add <files>`).
   - Commit using Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`).
   - Push to `origin develop` (`git push -u origin develop` on first push, then `git push`). If `github` remote is also used, push there only when requested or configured.

## Validation

1. Run `git status` and `git log -1 --oneline` to confirm a clean working tree on `develop`.
