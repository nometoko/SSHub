# AGENTS.md

## Project context
- This repository is a macOS-only Swift Package app.
- The app imports `SwiftUI`, so Linux-based environments are not expected to build or run the app successfully.
- The source of truth for app-level validation is macOS CI.

## Validation
- In Linux-based Codex environments, `swift build` or `swift test` may fail only because `SwiftUI` is unavailable. Treat that as an expected environment limitation, not as a product regression by itself.
- In Codex Linux environments, do not run `swift build` as a default validation step for this repository.
- Prefer static review and targeted pure-logic tests in Codex instead of app build validation.
- Before committing locally, run `swiftlint lint --strict --no-cache`.
- Do not rely on Linux execution for `SwiftUI` app behavior.
- GitHub Actions runs macOS validation in `.github/workflows/macos-swift.yml`.
- Prefer macOS GitHub Actions results over Linux container results when they disagree.
- Use GitHub Actions as the validation source of truth for:
  - lint
  - macOS build
  - macOS test
  - macOS coverage
- When changing app/UI code, keep the project buildable on macOS CI even if Linux `swift build` is unavailable.

## Review reporting
- If Linux validation fails because of missing `SwiftUI` support, report it as an expected environment limitation.
- Distinguish expected environment failures from real code regressions.
- If macOS GitHub Actions build/test/coverage fails, treat that as actionable.

## Review guidelines
- Prefer immutable identifiers for update/delete operations.
- Flag code that relies on full struct equality when mutable fields can change asynchronously.
