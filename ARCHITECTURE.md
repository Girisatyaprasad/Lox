# Lox Architecture Plan

## Status and scope

This document describes the target architecture and a staged migration plan for the existing Flutter application. It is a plan, not a claim that the proposed modules already exist. The first migration pass is a structural refactor: preserve current user-visible behavior, the JSON document format, and Android integration. Do not add live wallpapers, segmentation, effects, or other features as part of that pass.

The existing implementation is concentrated in `lib/main.dart`; `lib/document.dart` owns the document model and JSON conversion, and `lib/transform.dart` owns some transform math. The proposed structure separates those responsibilities without requiring a wholesale rewrite.

## Architectural principles

- Organize code by feature, with presentation, domain, and data/infrastructure responsibilities kept distinct.
- Keep domain entities and deterministic transformation algorithms free of Flutter widgets, plugin APIs, Android APIs, and filesystem operations.
- Use immutable document and editor state. Make changes explicit and publish a new state after each operation.
- Use repositories and gateways at boundaries for project persistence, media access, export, and wallpaper application.
- Use Riverpod for presentation state and dependency injection. Keep widgets focused on displaying state and forwarding user actions.
- Share the composition renderer between the on-screen preview and PNG capture so exported pixels match the rendered design.
- Preserve current editing semantics during extraction. Add behavior changes only in separately scoped work after the migration.
- Prefer cohesive modules over one-class-per-file boilerplate. Split files when ownership, change cadence, or testability benefits from it.

## Proposed project tree

The following is the target Dart structure. Android Gradle files, manifests, resources, wrapper, and the existing GitHub Actions workflow remain in place. Names marked **existing** identify code that exists today; all other paths are proposed destinations or new modules.

```text
lib/
├── main.dart                                      # Existing entry point; reduce to runApp/provider scope
├── app/
│   ├── lox_app.dart                               # App widget, theme, root screen
│   └── providers.dart                             # Riverpod dependency wiring
├── core/
│   ├── domain/
│   │   ├── studio_document.dart                   # Immutable document entity
│   │   ├── studio_layer.dart                      # Immutable layer and LayerKind
│   │   └── layer_transform.dart                   # Immutable transform value object
│   └── errors/
│       └── app_failure.dart                       # Small typed failures at app boundaries
└── features/
    ├── editor/
    │   ├── domain/
    │   │   └── transform_engine.dart              # Pure move, resize, scale, rotate operations
    │   └── presentation/
    │       ├── editor_screen.dart                  # Screen layout and action wiring
    │       ├── editor_view_model.dart              # Editor commands and state transitions
    │       ├── editor_state.dart                   # Immutable document, selection, tool, history flags
    │       └── widgets/
    │           ├── canvas_stage.dart               # Stage geometry, gestures, selection/handle overlay
    │           ├── layer_renderer.dart             # Draw one document layer
    │           ├── composition_renderer.dart       # Flutter composition shared by preview and export
    │           ├── property_inspector.dart         # Typography, appearance, and transform controls
    │           └── layer_panel.dart                # Reorder, visibility, lock, duplicate, delete
    ├── projects/
    │   ├── domain/
    │   │   └── project_repository.dart             # Load/list/save repository contract
    │   └── data/
    │       ├── local_project_repository.dart       # App-private project storage
    │       ├── project_asset_store.dart             # Imported image/font storage and resolution
    │       └── serialization/
    │           └── document_codec.dart              # JSON format and compatibility mapping
    ├── media/
    │   └── data/
    │       ├── device_media_importer.dart           # Device image/font selection and import
    │       └── imported_font_loader.dart            # Register stored fonts with Flutter
    ├── export/
    │   ├── domain/
    │   │   └── png_exporter.dart                    # Export request/result contract
    │   └── data/
    │       └── canvas_png_exporter.dart             # Capture shared Flutter composition and persist PNG
    └── wallpaper/
        ├── domain/
        │   └── wallpaper_gateway.dart               # Static wallpaper application contract
        └── data/
            └── android_wallpaper_gateway.dart       # MethodChannel adapter for Android

test/
├── core/
│   ├── studio_document_test.dart
│   └── transform_engine_test.dart
├── features/
│   ├── editor/
│   │   ├── editor_view_model_test.dart
│   │   └── editor_screen_test.dart
│   ├── projects/
│   │   └── local_project_repository_test.dart
│   └── export/
│       └── canvas_png_exporter_test.dart
└── (existing tests retained or moved into these locations)
```

`StudioDocument`, `StudioLayer`, and `LayerKind` live in core domain files, alongside the `LayerTransform` value object. `document_codec.dart` belongs to projects data/serialization: domain entities do not encode, decode, or depend on JSON. `layer_transform.dart` represents transform values; `transform_engine.dart` performs operations on them. These two roles are distinct and avoid duplicating transform algorithms.

The proposed tree does not introduce a generalized rendering framework. `composition_renderer.dart` is the existing Flutter composition expressed as a reusable widget. Advanced masking, depth, and live wallpaper modules are outside this migration.

## Module responsibilities and existing-code mapping

| Target module | Responsibility | Existing code to move or adapt |
|---|---|---|
| `app/lox_app.dart` | Material app, theme, root route/screen. | `LockStudioApp` from `lib/main.dart`. |
| `app/providers.dart` | Construct repository/service implementations and expose Riverpod providers. | New wiring; current constants and objects are constructed directly in `main.dart`. |
| `core/domain/studio_document.dart` and `studio_layer.dart` | Immutable document/layer entities and `LayerKind`. | `StudioDocument` and `StudioLayer` from `lib/document.dart`; screen edits become `copyWith` value replacements. |
| `core/domain/layer_transform.dart` | Immutable transform value (position, size, independent scales, rotation). | Transform fields currently stored directly on `StudioLayer` in `lib/document.dart`. |
| `features/projects/data/serialization/document_codec.dart` | Encode/decode JSON and map legacy fields, outside the domain layer. | JSON methods from `lib/document.dart`; Stage 1 preserves their keys, defaults, and value meanings. |
| `core/errors/app_failure.dart` | Small shared failure types where callers need actionable error handling. | Error strings and catch sites currently inline in `main.dart`; add only where useful. |
| `features/editor/domain/transform_engine.dart` | Deterministic, UI-independent move/resize/scale/rotation math. | Move/resize/scale from `lib/transform.dart` and rotation math in `_layerWidget`. |
| `features/editor/presentation/editor_state.dart` | Immutable view state: document, selected layer, active tool, and undo/redo availability. | Fields in `_EditorScreenState`. |
| `features/editor/presentation/editor_view_model.dart` | Commands for layer selection/mutation, transforms, panels, history, and orchestration of repository/service requests. | `_checkpoint`, `_undoAction`, `_redoAction`, `_mutate`, `_addLayer`, plus mutation handlers in `lib/main.dart`. |
| `features/editor/presentation/editor_screen.dart` | Screen layout and event forwarding; no filesystem or Android implementation. | `EditorScreen`, `_topBar`, `_bottomBar`, and UI composition from `lib/main.dart`. |
| `features/editor/presentation/widgets/canvas_stage.dart` | Canvas dimensions, pointer gesture lifecycle, hit selection, and selection/transform affordances. | `_canvas` and the `GestureDetector` setup in `_layerWidget`. |
| `features/editor/presentation/widgets/layer_renderer.dart` | Render text, clock, date, or image for one layer. | Content selection, `_clockText`, and layer `Text`/`Image.file` rendering from `_layerWidget`. |
| `features/editor/presentation/widgets/composition_renderer.dart` | Render background and ordered layers from document plus render context. | Full stack in `_canvas`, including the current gradient and `_CarPainter` fallback. |
| `features/editor/presentation/widgets/property_inspector.dart` | Contextual controls and dialogs for layer typography, appearance, and transform. | `_propertyPanel`, `_editText`, `_editDateFormat`, and `_editColor`. |
| `features/editor/presentation/widgets/layer_panel.dart` | Layer ordering and layer actions. | `_showLayers`. |
| `features/projects/domain/project_repository.dart` | Save, load, and enumerate projects independent of local storage. | New interface around current save/open behavior. |
| `features/projects/data/local_project_repository.dart` | App-private project files, JSON reads/writes, listing, and filename handling. | `_projectDir`, `_save`, and project enumeration/open code from `_openProjects`. |
| `features/projects/data/project_asset_store.dart` | Copy, locate, and resolve project image/font assets. | File-copy portions of `_pickWallpaper`, `_pickFont`, and `_loadFonts`. Initial implementation wraps current app-private storage locations. |
| `features/media/data/device_media_importer.dart` | Adapt `file_picker` and copy selected image/font files into asset storage. | `_pickWallpaper` and `_pickFont`. |
| `features/media/data/imported_font_loader.dart` | Load persisted font bytes into Flutter’s `FontLoader`. | Font registration in `_pickFont` and `_loadFonts`. |
| `features/export/domain/png_exporter.dart` | Define an export request/result without exposing widget state to domain logic. | New contract around PNG export. |
| `features/export/data/canvas_png_exporter.dart` | Capture the reusable composition at requested resolution and write PNG output. | RepaintBoundary capture and file output in `_export`. |
| `features/wallpaper/domain/wallpaper_gateway.dart` | Describe applying a static exported image to a target. | New interface around current lock/home action. |
| `features/wallpaper/data/android_wallpaper_gateway.dart` | Encapsulate MethodChannel name, call parameters, and platform errors. | `_wallpaper` and channel invocation in `_export`; native endpoint remains in `MainActivity.kt`. |
| `lib/main.dart` | Minimal `main()` and root provider scope. | Existing `main()` and app construction, after other code is extracted. |

## Dependency directions

```text
Flutter widgets
      │ read state / send intents
      ▼
Editor ViewModel ───────────────► Domain entities + transform engine
      │                                      ▲
      │ calls contracts                     │ implements/uses
      ├────────► ProjectRepository ◄──────── LocalProjectRepository
      ├────────► PngExporter       ◄──────── CanvasPngExporter
      ├────────► WallpaperGateway  ◄──────── AndroidWallpaperGateway
      └────────► Media/import services ◄──── DeviceMediaImporter / FontLoader

Riverpod providers construct concrete data/platform implementations and supply
those implementations to the ViewModel. Domain code imports neither Flutter nor
plugins, filesystem APIs, or Android code.
```

`core/domain` is the innermost Dart-only layer. Project serialization lives in `features/projects/data/serialization` and depends inward on the domain entities; the domain never imports the codec or JSON library. Feature domain code may use core domain types. Presentation may depend on feature/core domain types and Riverpod. Data implementations may depend on domain contracts and the relevant Flutter/plugin APIs. Domain code must not import presentation or data modules. Android code communicates through the wallpaper adapter/MethodChannel, not through document entities.

## State management and dependency injection

Use `flutter_riverpod` with a root `ProviderScope` and providers in `app/providers.dart`. Bind `ProjectRepository`, asset/media services, `PngExporter`, and `WallpaperGateway` to concrete implementations there. Tests override providers with in-memory/fake implementations.

Use an `EditorViewModel` backed by Riverpod `Notifier`/`NotifierProvider` for synchronous editor state and commands. The immutable `EditorState` contains the active document, selected layer ID, active panel/tool, and undo/redo availability. The ViewModel publishes a new state after each operation; widgets render that state and call commands rather than mutating document objects.

Preserve current snapshot-style undo/redo semantics initially: checkpoint before a logical edit/gesture, retain the existing history limit of 80, clear redo on a new edit, and ensure one continuous gesture is one undo step. Avoid migrating to command/event history until measurements show a need. Use asynchronous provider/view-model methods only for file or platform work; keep drag updates synchronous and lightweight.

Riverpod is a deliberate dependency addition. The existing app uses one `StatefulWidget`, so there is no legacy state framework to reconcile. Migrate incrementally: first move state unchanged behind the ViewModel API, then convert the screen to consume it.

## Keeping document, preview, and export consistent

The ViewModel owns the current immutable `StudioDocument`; all editing operations produce updated document/layer values. `EditorScreen` passes that same document and selected ID into `CanvasStage` and `CompositionRenderer`.

`CompositionRenderer` remains in the Flutter rendering/presentation boundary; it is not a domain service. It is the single definition of the background and ordered layer appearance. The editor preview wraps it with selection/gesture UI; export captures the same renderer without editor affordances. Clock/date rendering receives a `RenderContext` (including a captured `DateTime`) so a single export uses one consistent time value, while the live preview continues to receive updated time values according to current behavior. Device-size layout may scale the renderer, but the document’s normalized layout and export dimensions remain based on document width/height.

PNG export must not reconstruct text, dates, or layers in a second rendering implementation. A Flutter-boundary capture/export adapter requests a capture of `CompositionRenderer` at the document’s target resolution, then stores the resulting PNG. Tests compare the resulting dimensions and verify that selection handles are absent. The current Android behavior remains applying that static PNG through `WallpaperManager`; this plan does not claim that the exported clock remains live on the system lock screen.

## Migration sequence and validation checkpoints

Each stage is a separate, reviewable change. Keep the existing tests passing at every checkpoint; add focused tests before removing old implementations. Run the project’s existing CI commands (`dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`) at the relevant checkpoints.

1. **Extract domain entities and transformation logic.** Move document/layer types and transforms into the core/editor domain modules. Make values immutable and transformations deterministic. Keep JSON keys and defaults stable via a codec. Add round-trip, default-value, independent-axis, lock, and transform-bound tests. **Checkpoint:** current document tests and widget behavior still pass; JSON fixtures produced before migration decode identically.
2. **Introduce repository contracts and persistence implementations.** Add project and asset storage boundaries, then route save/open/list through `LocalProjectRepository`. Initially preserve the current private `projects/`, `assets/`, and `fonts/` storage conventions and the saved JSON shape. Add repository tests for list/save/load and missing files. **Checkpoint:** projects saved by the current build still open, and newly saved documents reopen with equivalent layers/assets.
3. **Extract editor state/history into a ViewModel.** Introduce immutable `EditorState`, Riverpod providers, and ViewModel commands. Port operations one at a time; preserve checkpoint timing, history limit, selection, and gesture semantics. **Checkpoint:** add ViewModel tests for move/resize/scale, selection, edit undo/redo, layer operations, and continuous gesture undo; existing widget tests continue to pass.
4. **Extract canvas and layer rendering.** Move stage, layer, and composition rendering into editor widgets. Keep list order, current font sizing, time/date formatting, opacity, clipping, and gesture deltas unchanged. **Checkpoint:** widget tests cover live clock/date visibility, layer stacking, tap/drag/pinch behavior, and selected/unselected preview rendering.
5. **Isolate import, export, and platform integrations.** Add media importer/font-loader services, the PNG exporter, and the wallpaper gateway. Supply fakes for tests; keep the existing MethodChannel contract and Android `WallpaperManager` target behavior. **Checkpoint:** verify imported assets reopen, exported PNG uses the shared renderer and correct dimensions, and channel calls request the same lock/home targets.
6. **Simplify application initialization.** Move `LockStudioApp` to `app/lox_app.dart`; leave `main.dart` as initialization and `ProviderScope` wiring. Remove obsolete code only after all call sites and tests use the new modules. **Checkpoint:** formatting, analysis, unit/widget tests, and debug APK CI all pass; perform a real-device smoke test for import, edit, save/reopen, export, and static wallpaper application.

## Saved-project and behavior risks

- **JSON compatibility:** Current JSON writes `schemaVersion: 1`, `title`, `width`, `height`, `layers`, and layer keys including `kind`, `imagePath`, `x`, `y`, `width`, `height`, `rotation`, `scaleX`, `scaleY`, `opacity`, `color`, `fontFamily`, `fontSize`, `letterSpacing`, `visible`, `locked`, `use24Hour`, `showSeconds`, and `verticalClock`. Keep these keys, enum names, defaults, and numeric meanings stable during extraction. If a later model changes shape, translate it in the codec and add versioned migrations rather than silently rewriting saved files.
- **Mutable to immutable conversion:** Copying, equality, and list ordering can subtly change. Add model and ViewModel tests before routing UI operations through the new values.
- **History semantics:** A checkpoint on gesture start differs from checkpointing on every update. Preserve the current one-step gesture behavior and slider checkpoint boundaries.
- **Asset paths:** Existing projects contain absolute image paths under the app-private documents directory; font family names resolve to files in the separate `fonts/` directory. The first repository adapter must preserve those locations so existing projects remain usable. Asset packaging, relative IDs, and portability require a later codec migration and explicit old-path resolver; do not bundle that behavior change into the pure refactor.
- **Rendering parity:** Moving widgets can change layout constraints, clipping, painter order, font scale, or `DateTime` evaluation timing. Use preview/export widget tests and a real-device comparison before removing the old renderer.
- **Platform boundary:** Keep the current `freeform_studio/wallpaper` channel name and `setWallpaper` arguments (`path`, `which`) until the Android adapter and native host are migrated together. Android’s API applies a static image and does not replace the native lock-screen clock.
- **Dependency/toolchain risk:** Riverpod adds a package and lockfile change. Pin/lock it through normal pub resolution, then validate with the same Flutter version and CI workflow before proceeding.
