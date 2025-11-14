# Repository Guidelines

## Project Structure & Module Organization
- `BoberHouse/` holds the SwiftUI app; keep top-level files minimal and push screen-specific logic into `Views/` and `ViewModels/`.
- `Models/` defines SwiftData entities (e.g., `TaskTemplate`) shared across the alternation engine and persistence.
- `Services/` wraps sync, scheduling, and alternation rules; prefer adding integrations here to centralize async work.
- `Design/` maintains theme constants and preview fixtures; keep new mock data alongside `PreviewData.swift`.
- Static assets live under `Resources/Assets.xcassets`; preview-only assets belong in `Resources/Preview.xcassets`.
- Long-form system notes belong in `Docs/` (see `sync-and-notifications.md` for the expected depth).

## Build, Test, and Development Commands
- `open BoberHouse.xcodeproj` — load the project in Xcode for simulator and device runs.
- `xcodebuild -scheme BoberHouse -destination 'platform=iOS Simulator,name=iPhone 15' clean build` — CI-friendly build step.
- `xcodebuild test -scheme BoberHouse -destination 'platform=iOS Simulator,name=iPhone 15'` — executes unit/UI tests once a test target is wired up.
- Use Xcode previews (`⌘⌥↩`) in `Views/` to validate layout tweaks quickly.

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines: types `PascalCase`, functions/properties `camelCase`, and enum cases `lowerCamelCase`.
- Indent with four spaces; rely on Xcode's `Editor > Structure > Re-Indent` to tidy diffs.
- Keep view modifiers readable by stacking one per line and extracting reusable components under `Views/Components/` (create the folder when needed).
- Store preview-only mocks in `Design/PreviewData.swift` and gate debugging helpers with `#if DEBUG`.

## Testing Guidelines
- Add a `BoberHouseTests` target for unit coverage; mirror app folders (e.g., `ServicesTests/`) and suffix files with `Tests`.
- When a test target exists, run it via the `xcodebuild test` command above or from Xcode (`⌘U`).
- Favor deterministic SwiftData fixtures—seed containers with in-memory stores and explicit `UUID` values.
- Document manual QA flows in PR descriptions until automated UI coverage is in place.

## Commit & Pull Request Guidelines
- Local history is not bundled here; adopt short, imperative summaries (e.g., `Add sync envelope validation`). Use optional scope tags when helpful (`Sync:`).
- Reference tracked work in the body (`Closes #42`) and call out migrations or schema changes near the top.
- PRs should include: purpose summary, testing notes (commands + results), screenshots for UI-affecting changes, and outstanding follow-ups.
- Request at least one review before merging; keep branches current with `main` via rebase to maintain linear history.
