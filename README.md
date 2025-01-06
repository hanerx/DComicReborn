# dcomic

[![Flutter][flutter-badge]][deps-flutter-version]

DComic Ver2.0

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build From Source

### APK

Make sure your Flutter version `>=3.24.0 (maybe <3.27.0)`, then just run `flutter build apk`.
If a release version needs to be built, a signing key must be provided,
follow ["Sign your app"][g-sign-app] get more information.

### q. my pubspec.lock modified after exec `flutter pub get`

The main reason is that this project's source uses a China mirror,
you can get more information from ["Using Flutter in China"][flt-cn].

If you don't mind the uncommitted changes caused by pubspec.lock changing every time,
you can ignore it in `.git/info/exclude`.
For other cases, please follow ["Using Flutter in China"][flt-cn] guide to add necessary environment variables.

Luckily with vscode, you can add json configs below in your project's `settings.json` file:

```json
"dart.env": {
  "PUB_HOSTED_URL": "https://pub.flutter-io.cn",
  "FLUTTER_STORAGE_BASE_URL": "https://storage.flutter-io.cn"
},
"terminal.integrated.env.windows": {
  "PUB_HOSTED_URL": "https://pub.flutter-io.cn",
  "FLUTTER_STORAGE_BASE_URL": "https://storage.flutter-io.cn"
}
```

## ORM Database

- run `flutter packages pub run build_runner build`
- or run `flutter packages pub run build_runner watch`

[flutter-badge]: https://img.shields.io/badge/_Flutter_-3.24.x-grey.svg?&logo=Flutter&logoColor=white&labelColor=blue
[deps-flutter-version]: https://github.com/flutter/flutter/tree/3.24.0
[g-sign-app]: https://developer.android.com/studio/publish/app-signing
[flt-cn]: https://docs.flutter.dev/community/china