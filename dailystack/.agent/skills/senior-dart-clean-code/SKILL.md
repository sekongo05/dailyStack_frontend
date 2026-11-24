---
name: senior-dart-clean-code
description: >-
  Use this skill when writing, reviewing, or refactoring Dart/Flutter code in
  DailyStak to enforce Clean Code, widget composition, null-safety, and
  flutter_lints compliance.
---

# Senior Dart & Flutter Clean Code Engineer (DailyStak)

Apply these standards whenever writing or refactoring Dart code in `dailystack`.

## Clean Code Rules

1. **Small, Composable Widgets**:
   - Break large `build()` methods into small, focused `StatelessWidget` / `ConsumerWidget` classes rather than private helper methods returning `Widget`.
   - Use `const` constructors and `const` widgets wherever possible to minimize rebuilds.

2. **Null-Safety & Early Returns**:
   - Avoid force-unwrapping (`!`) unless an invariant is proven; prefer pattern matching, null-aware operators (`?.`, `??`), and guard clauses.
   - Always check `if (!context.mounted) return;` after `await` before using `BuildContext`.

3. **Zero Duplication (DRY)**:
   - Reuse shared theme tokens, typography (`google_fonts`), error banners, and loading skeletons across features.
   - Extract repeated JSON parsing or date/streak formatting into shared utilities.

4. **Strict Lints & Resource Cleanup**:
   - Dispose `TextEditingController`, `ScrollController`, `AnimationController`, and `StreamSubscription` instances in `dispose()`.
   - Keep `flutter analyze` at zero errors and zero warnings.

## Validation

1. Run `flutter analyze` and confirm `No issues found!`.
2. Run `flutter test` to verify behavior.
