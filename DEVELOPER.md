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

## iOS dependencies

The iOS plugin is distributed as a Swift package (`ios/flutter_authgear/Package.swift`) only, the same as the Authgear iOS SDK.
There is no podspec, so the plugin does not support apps that build with CocoaPods.
`environment.flutter` in `pubspec.yaml` is at least 3.50.0. Flutter enables Swift Package Manager by default since 3.44.0,
but before 3.50.0 it fails to resolve the Swift package of the plugin when it is a git dependency, or a path dependency
whose directory is not named `flutter_authgear`, such as the example app (https://github.com/flutter/flutter/issues/186881).

The example app does not use CocoaPods. Its only non-Flutter iOS dependency is WechatOpenSDK,
which is added as the Swift package https://github.com/yanyin1986/WechatOpenSDK, pinned to an exact version in the Xcode project.
