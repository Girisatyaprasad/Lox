# Freeform Personalization Studio

An offline-first Flutter editor for composing dynamic lock-screen artwork. Projects are JSON documents stored in app-private storage; imported wallpapers and fonts stay on device.

## Current vertical slice

- Phone-shaped canvas with imported wallpaper, live time, dynamic date, and editable text/image layers.
- Tap to select; drag to move; pinch to scale and rotate; resize width and height independently with transform controls.
- Toggle 12/24-hour time, vertical/horizontal clock layout, and seconds; set type size and spacing, import TTF/OTF fonts, edit date formats, and set color/opacity.
- Layer list supports reorder, visibility, lock, duplicate, and delete.
- In-memory undo/redo, local save/reopen, composition preview, and PNG export.
- Android platform channel applies an exported static image to the lock screen or home screen using `WallpaperManager`.

Layer positions and dimensions are normalized against the 1080 × 2400 document canvas. Each layer serializes its own x/y position, width/height, scale X/Y, rotation, opacity, visibility, lock state, and layer order. The renderer uses the current time for clocks and the current locale/device date for date layers. Imported fonts are copied into app storage and loaded when a saved project is reopened.

## Android integration limits

The public Android `WallpaperManager` API lets an app set static system and lock wallpapers. It cannot replace the native lock-screen clock with an app-rendered clock. The exported PNG therefore contains a snapshot of this composition; live time and dates remain live in the editor and preview only. A future live wallpaper service can animate the home screen, but it still cannot replace the system lock-screen clock through public APIs.

Samsung Good Lock is a separate, manufacturer-specific path. Samsung documents LockStar, Wonderland, and ClockFace as Good Lock modules, with Watch Face Studio plugins used to create compatible content. This app does not ship a Good Lock plugin or claim a direct LockStar/ClockFace integration. Samsung support and module availability vary by device, One UI version, and region. See [Samsung's Good Lock plugin FAQ](https://developer.samsung.com/watch-face-studio/plugin/goodlock/faq.html) and [plugin overview](https://developer.samsung.com/watch-face-studio/plugin/overview.html).

## Develop and validate

Flutter 3.29.3 is the pinned toolchain (Dart 3.7.2). On a machine with Flutter and the Android SDK:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

GitHub Actions runs formatting, analysis, tests, and a debug APK build on pushes, pull requests, and manual dispatch. The APK is uploaded as the `freeform-studio-debug-apk` workflow artifact.

## Planned work

Direct edge and corner resize gestures, renaming layers, richer typography/effects, masks and foreground cutouts, bigger accessibility handles, and a live wallpaper service are follow-up milestones. The first implementation keeps project data and Android wallpaper integration separate from canvas rendering.
