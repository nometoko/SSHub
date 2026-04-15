# AGENTS.md

## Project context
- This repository is a macOS-only Swift Package app.
- The app imports `SwiftUI`, so local validation in Linux-like environments is limited.
- The source of truth for app-level validation is macOS CI.

## Validation
- Prefer `swift build` for local validation in Codex.
- Do not rely on Linux execution for `SwiftUI` app behavior.
- GitHub Actions runs macOS validation in `.github/workflows/macos-swift.yml`.
- When changing app/UI code, keep the project buildable with `swift build`.

## Review guidelines
- Prefer immutable identifiers for update/delete operations.
- Flag code that relies on full struct equality when mutable fields can change asynchronously.
