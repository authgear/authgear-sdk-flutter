# Changelog

## Unreleased

### Added

- `authenticate()` accepts an optional `resource` (RFC 8707 resource indicator). Access tokens of the resulting session, including refreshed ones, have `aud` set to that resource URI.
- `authenticate()` accepts optional `scopes` to request the scopes of the API resource given in `resource`. They are merged with the scopes required by the SDK, so the scopes required by the SDK are always requested.
- `authenticateAnonymously()`, `promoteAnonymousUser()` and `authenticateBiometric()` accept optional `resource` and `scopes`, with the same meaning as in `authenticate()`.
- `makePreAuthenticatedURL()` accepts an optional `resource`.
- `configure()` accepts optional `resource` and `scopes` as defaults. `resource` applies to `authenticate()`, `authenticateAnonymously()`, `promoteAnonymousUser()`, `authenticateBiometric()` and `makePreAuthenticatedURL()`. `scopes` applies to the first four. A value given to a method replaces the default; the scopes required by the SDK are always requested. `enableBiometric()` never sends them.

## 5.1.0

### Fixed

- The SDK now clears the session when a token refresh fails with `invalid_dpop_proof` (previously only `invalid_grant` was handled), so a restored refresh token that no longer matches the DPoP key no longer leaves `sessionState` stuck at `authenticated` with refresh retrying forever.

### Added

- `SessionStateChangeEvent.error` now carries the error that triggered a session clear (e.g. an `OAuthException` with `invalid_grant` or `invalid_dpop_proof`) when `reason == SessionStateChangeReason.invalid`. It is `null` for all other reasons.

### Deprecated

- `SettingsPage.identity` is deprecated. Use `SettingsPage.settings` to list identities, and methods like `changeEmail`/`changePhone` to change them.

## 5.0.0

### Breaking changes

- Upgraded Flutter tooling to 3.44.5 (from 3.32.8). Consuming apps should be on a compatible Flutter version.
- Android: raised the Android Gradle Plugin to 9.0.1 (from 8.7.3), Kotlin to 2.3.20 (from 2.1.0), `compileSdk` to 36 (from 35), and the Java/Kotlin build target to 17 (from 11). Consuming apps must build with a JDK 17 toolchain and an AGP/Gradle version compatible with AGP 9.
