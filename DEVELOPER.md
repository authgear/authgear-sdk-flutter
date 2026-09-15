## How to publish a new version

Read https://dart.dev/tools/pub/publishing

1. Bump the version in `pubspec.yaml` and update `CHANGELOG.md`, in a new commit with the message `Bump version to VERSION`, e.g.:
   ```
   Bump version to 5.1.0
   ```
2. Run `cd example && flutter pub get` to update the version in `example/pubspec.lock`, and commit that.
3. Open a PR with these commits, and merge it.
4. Run `flutter pub publish`.
5. `git tag VERSION COMMIT`, then push the tag to `authgear` (e.g. `git push authgear VERSION`).

## Known issue


### dartdoc failed: type 'PropertyAccessImpl' is not a subtype of type 'IdentifierImpl' in type cast

This bug is tracked in https://github.com/dart-lang/dartdoc/issues/2934

The solution is to use a newer dartdoc.

```
flutter pub global activate dartdoc
flutter pub global run dartdoc
```
