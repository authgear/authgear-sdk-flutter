## How to publish a new version

Read https://dart.dev/tools/pub/publishing

Basically you bump the version with a new commit, and then run `flutter pub publish`

## Known issue


### dartdoc failed: type 'PropertyAccessImpl' is not a subtype of type 'IdentifierImpl' in type cast

This bug is tracked in https://github.com/dart-lang/dartdoc/issues/2934

The solution is to use a newer dartdoc.

```
flutter pub global activate dartdoc
flutter pub global run dartdoc
```
