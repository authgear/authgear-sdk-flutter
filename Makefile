API_ISSUER ?= "invalid"
API_KEY ?= "invalid"
API_KEY_PATH ?= ./AuthKey_invalid.p8

.PHONY: fastlane-api-key-json
fastlane-api-key-json:
	mkdir -p ./build
	jq --slurp --raw-input > ./build/fastlane-api-key.json \
		--arg key_id $(API_KEY) \
		--arg issuer_id $(API_ISSUER) \
		'{key_id: $$key_id, issuer_id: $$issuer_id, key: .}' \
		$(API_KEY_PATH)

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
	bundle exec fastlane runner_build_ios_app skip_codesigning:1

.PHONY: example-build-ios-app
example-build-ios-app:
	bundle exec fastlane runner_build_ios_app FLUTTER_BUILD_NAME:1.0 FLUTTER_BUILD_NUMBER:$(shell date +%s)

.PHONY: example-upload-ios-app
example-upload-ios-app:
	bundle exec fastlane upload_ios_app ipa:./build/Release/iOS/Runner/Runner.ipa

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
	dart format --set-exit-if-changed lib
