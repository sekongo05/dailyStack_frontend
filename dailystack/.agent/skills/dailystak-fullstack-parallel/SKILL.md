---
name: dailystak-fullstack-parallel
description: >-
  Use this skill when implementing a full-stack feature, fixing a cross-stack
  bug, or working simultaneously on the DailyStak Spring Boot backend and
  Flutter frontend in parallel.
---

# DailyStak Parallel Full-Stack Workflow

Use this workflow to develop backend and frontend features concurrently without contract drift.

## Repositories
- **Backend (Spring Boot 4 / Java 21)**: `/Users/macbookairm1/Desktop/DailyStak`
- **Frontend (Flutter / Dart)**: `/Users/macbookairm1/Desktop/DailyStaskFrontend/dailystack`
- **Shared API Contract**: `/Users/macbookairm1/Desktop/DailyStak/API_INTEGRATION_FRONTEND.md`

## Stage 1: Lock the API Contract First
1. Before writing code in parallel, agree on and update `API_INTEGRATION_FRONTEND.md` with:
   - HTTP method, path (`/api/v1/...`), auth requirement, and query params.
   - Exact JSON request/response field names, types, nullability, and status codes.

## Stage 2: Parallel Execution (2 Subagents)
Launch two subagents in the same turn (using `invoke_subagent` or `run_workflow` `parallel`):
1. **Backend Subagent** (`Cwd`: `/Users/macbookairm1/Desktop/DailyStak`):
   - Follow `dailystak-dev-workflow` (`senior-spring-architect`, `senior-postgres-performance`, `senior-clean-code`, `senior-testing-qa`, `senior-security-audit`).
   - Implement Controller, Service, Repository, DTOs, and integration tests.
2. **Frontend Subagent** (`Cwd`: `/Users/macbookairm1/Desktop/DailyStaskFrontend/dailystack`):
   - Follow `dailystak-flutter-workflow` (`senior-flutter-architect`, `senior-dart-clean-code`, `senior-flutter-testing`, `senior-flutter-security`).
   - Implement models, Dio repository, Riverpod provider, GoRouter route, UI widgets, and unit/widget tests against the locked contract.

## Stage 3: Cross-Stack Verification
1. Compare the backend DTOs/controllers against the frontend `fromJson`/`toJson` models and endpoints.
2. Run both verification suites in parallel via:
   `/Users/macbookairm1/Desktop/DailyStak/.agent/skills/dailystak-fullstack-parallel/scripts/verify-all.sh`
3. When ready to push, follow `git-commit-push-dev` in **each** repository on its `develop` branch.
