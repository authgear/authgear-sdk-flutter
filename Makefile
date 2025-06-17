.PHONY: example-flutter-pub-get
example-flutter-pub-get:
	cd ./example; flutter pub get

.PHONY: example-flutter-test
example-flutter-test:
	cd ./example; flutter test

.PHONY: example-flutter-analyze
example-flutter-analyze:
	cd ./example; flutter analyze --no-fatal-infos

.PHONY: example-dart-format
example-dart-format:
	cd ./example; dart format --set-exit-if-changed lib

.PHONY: example-pod-install
example-pod-install:
	cd ./example/ios; bundle exec pod install

.PHONY: example-build-unsigned-ios-app
example-build-unsigned-ios-app:
	bundle exec fastlane ios runner_build_ios_app skip_codesigning:1

.PHONY: example-build-ios-app
example-build-ios-app:
	bundle exec fastlane ios runner_build_ios_app FLUTTER_BUILD_NAME:1.0 FLUTTER_BUILD_NUMBER:$(shell date +%s)

.PHONY: example-upload-ios-app
example-upload-ios-app:
	bundle exec fastlane ios upload_ios_app ipa:./build/Release/iOS/Runner/Runner.ipa

.PHONY: example-build-unsigned-android-aab
example-build-unsigned-android-aab:
	cd ./example/android; ./gradlew :app:bundleDebug

.PHONY: example-build-android-aab
example-build-android-aab:
	bundle exec fastlane android build_aab \
		VERSION_CODE:$(shell date +%s) \
		STORE_FILE:$(STORE_FILE) \
		STORE_PASSWORD:$(STORE_PASSWORD) \
		KEY_ALIAS:$(KEY_ALIAS) \
		KEY_PASSWORD:$(KEY_PASSWORD)

.PHONY: example-upload-android-aab
example-upload-android-aab:
	bundle exec fastlane android upload_aab \
		json_key:$(GOOGLE_SERVICE_ACCOUNT_KEY_JSON_FILE)

.PHONY: sdk-flutter-pub-get
sdk-flutter-pub-get:
	flutter pub get

.PHONY: sdk-flutter-test
sdk-flutter-test:
	flutter test

.PHONY: sdk-flutter-analyze
sdk-flutter-analyze:
	flutter analyze --no-fatal-infos

.PHONY: sdk-dart-format
sdk-dart-format:
	dart format --set-exit-if-changed lib
