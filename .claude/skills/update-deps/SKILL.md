---
description: Audit and update vulnerable dependencies. Checks Dart/Flutter (pubspec.yaml) and Ruby gems (Gemfile.lock) for known CVEs, upgrades non-breaking vulnerable packages, and summarizes what was updated vs. what needs manual review.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit WebSearch WebFetch
---

Audit and update vulnerable dependencies in this Flutter/Ruby project. Follow these steps exactly.

## Step 1: Audit Ruby gems

Run `bundle-audit` to check for CVEs. Install it first if needed:

```
gem install bundler-audit --no-document 2>/dev/null; bundle-audit update && bundle-audit check
```

If `bundle-audit` is not available, run:

```
bundle exec gem list
```

Then use WebSearch to check the RubyGems advisory database for each gem.

Capture the list of vulnerable gems, their current versions, and the minimum patched versions.

## Step 2: Audit Dart/Flutter packages

Run `dart pub audit` in the root and in `example/`:

```
dart pub audit
cd example && dart pub audit
```

If `dart pub audit` returns "command not found" or is unavailable, read `pubspec.yaml` and `example/pubspec.yaml`, then use WebSearch to check each dependency against https://osv.dev for known vulnerabilities.

Capture the list of vulnerable packages, their current versions, and the minimum patched versions.

## Step 3: For each vulnerable dependency, research breaking changes

For each vulnerable dep found in steps 1–2:

1. Note the **current version** and the **minimum patched version**.
2. Use WebSearch or WebFetch to read the package's CHANGELOG, GitHub releases, or pub.dev changelog between those two versions.
3. Decide:
   - **Non-breaking**: fix is within the same major version with no documented breaking changes → mark for upgrade.
   - **Breaking**: fix requires a major version bump, or the changelog documents removed APIs, renamed classes, changed interfaces, or a migration guide → mark for manual review.

## Step 4: Upgrade non-breaking Ruby gems

For each non-breaking vulnerable Ruby gem, run:

```
bundle update <gem_name>
```

Verify the gem version in `Gemfile.lock` was updated to the patched version.

## Step 5: Upgrade non-breaking Dart packages

For each non-breaking vulnerable Dart package:

1. Update the version constraint in `pubspec.yaml` or `example/pubspec.yaml` to allow the patched version.
2. Run:
   ```
   dart pub upgrade <package_name>
   ```
   or for the example app:
   ```
   cd example && dart pub upgrade <package_name>
   ```

Verify the version in `pubspec.lock` / `example/pubspec.lock` was updated.

## Step 6: Verify no remaining vulnerabilities

Re-run the audit commands from steps 1 and 2 to confirm all upgraded packages are no longer flagged.

## Step 7: Present a summary to the user

Present a clear, structured summary:

---

### Dependency Audit Summary

**Updated (fixed automatically):**

| Package | Type | Old version | New version | CVE / Advisory |
|---------|------|-------------|-------------|----------------|
| ...     | Ruby/Dart | x.y.z | a.b.c | CVE-XXXX-XXXXX |

**Not updated (breaking changes — requires manual review):**

For each:
- **Package**: name (Ruby gem / Dart package)
- **Current version**: x.y.z
- **Patched version needed**: a.b.c
- **CVE / Advisory**: link or ID
- **Severity**: critical / high / medium / low
- **Breaking change summary**: brief description of what changed and what migration involves
- **Migration guide**: link if available

**No vulnerabilities found:** (list ecosystems with clean audits)

---

Ask the user: "Would you like help upgrading any of the breaking-change packages listed above? If so, let me know which ones and I'll walk through the migration."

## Notes

- This repo vendors gems at `vendor/bundle/`. Run all `bundle` commands from the repo root.
- The Gemfile only directly specifies `cocoapods` and `fastlane`; most lockfile entries are transitive. For a vulnerable transitive gem, check whether upgrading its parent (`cocoapods` or `fastlane`) pulls in the patched transitive version before editing any version constraints directly.
- Dart: `flutter_lints` is dev-only. Treat it as lower urgency than runtime dependencies (`crypto`, `http`).
- Always verify changelogs from the web before deciding non-breaking — do not guess.
