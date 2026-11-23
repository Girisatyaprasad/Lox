import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'core/domain/studio_document.dart';
import 'core/domain/studio_layer.dart';
import 'features/editor/domain/transform_engine.dart';
import 'features/projects/data/serialization/document_codec.dart';

const _ink = Color(0xff101113);
const _panel = Color(0xff1c1d20);
const _accent = Color(0xffc5ff60);
const _wallpaper = MethodChannel('freeform_studio/wallpaper');

void main() => runApp(const LockStudioApp());

class LockStudioApp extends StatelessWidget {
  const LockStudioApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Freeform Studio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: _ink,
          colorScheme:
              const ColorScheme.dark(primary: _accent, surface: _panel),
          sliderTheme: const SliderThemeData(
              activeTrackColor: _accent, thumbColor: _accent),
        ),
        home: const EditorScreen(),
      );
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  StudioDocument doc = StudioDocument(title: 'Redline');
  final GlobalKey _canvasKey = GlobalKey();
  final List<StudioDocument> _undo = [], _redo = [];
  final Map<String, double> _pinchScale = {};
  final Map<String, double> _pinchRotation = {};
  final Set<String> _loadedFonts = {};
  String? selectedId;
  bool _showSelection = true;
  String _activeTool = 'Transform';
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    final initialLayers = <StudioLayer>[
      StudioLayer(
          id: 'clock',
          name: 'Clock',
          kind: LayerKind.clock,
          x: .5,
          y: .39,
          width: .74,
          height: .39,
          fontSize: 290,
          color: 0xfff7f2ee),
      StudioLayer(
          id: 'date',
          name: 'Date',
          kind: LayerKind.date,
          x: .5,
          y: .59,
          width: .72,
          height: .06,
          fontSize: 66,
          color: 0xffffdf47),
    ];
    doc = doc.copyWith(layers: initialLayers);
    selectedId = 'clock';
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final activeClock = doc.layers
          .any((l) => l.kind == LayerKind.clock && l.showSeconds && l.visible);
      if (activeClock || DateTime.now().second == 0) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  StudioLayer? get selected {
    for (final layer in doc.layers) {
      if (layer.id == selectedId) return layer;
    }
    return null;
  }

  void _checkpoint() {
    _undo.add(doc.copy());
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    _redo.add(doc.copy());
    setState(() => doc = _undo.removeLast());
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    _undo.add(doc.copy());
    setState(() => doc = _redo.removeLast());
  }

  void _mutate(void Function() action) {
    _checkpoint();
    setState(action);
  }

  void _replaceLayer(StudioLayer updated) {
    final index = doc.layers.indexWhere((layer) => layer.id == updated.id);
    if (index < 0) return;
    final layers = [...doc.layers];
    layers[index] = updated;
    doc = doc.copyWith(layers: layers);
  }

  void _updateLayer(String id, StudioLayer Function(StudioLayer) update) {
    final index = doc.layers.indexWhere((layer) => layer.id == id);
    if (index < 0) return;
    _replaceLayer(update(doc.layers[index]));
  }

  Future<Directory> _projectDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/projects');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _renameProject() async {
    final controller = TextEditingController(text: doc.title);
    final title = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Project name'),
                content: TextField(controller: controller, autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Save'))
                ]));
    if (title != null && title.trim().isNotEmpty) {
      _mutate(() => doc = doc.copyWith(title: title.trim()));
    }
  }

  Future<void> _save() async {
    final dir = await _projectDir();
    final safe = doc.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/$safe.json');
    await file.writeAsString(DocumentCodec.encode(doc));
    if (mounted) _notice('Project saved on this device');
  }

  Future<void> _openProjects() async {
    final dir = await _projectDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        backgroundColor: _panel,
        builder: (ctx) => SafeArea(
              child: SizedBox(
                  height: 420,
                  child: Column(children: [
                    const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Your projects',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                    Expanded(
                      child: files.isEmpty
                          ? const Center(child: Text('No saved projects yet'))
                          : ListView(
                              children: files
                                  .map((f) => ListTile(
                                        leading: const Icon(
                                            Icons.dashboard_customize_outlined),
                                        title: Text(f.uri.pathSegments.last
                                            .replaceAll('.json', '')),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          final opened = DocumentCodec.decode(
                                              await f.readAsString());
                                          if (!mounted) return;
                                          await _loadFonts(opened);
                                          setState(() {
                                            doc = opened;
                                            selectedId = doc.layers.isEmpty
                                                ? null
                                                : doc.layers.last.id;
                                            _undo.clear();
                                            _redo.clear();
                                          });
                                          if (ctx.mounted) Navigator.pop(ctx);
                                        },
                                      ))
                                  .toList(),
                            ),
                    ),
                  ])),
            ));
  }

  Future<void> _pickWallpaper() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: false);
    if (result == null || result.files.single.path == null) return;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/assets');
    await dir.create(recursive: true);
    final path =
        '${dir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension ?? 'img'}';
    await File(result.files.single.path!).copy(path);
    _mutate(() {
      final layers = doc.layers
          .where((l) => !(l.kind == LayerKind.image && l.name == 'Wallpaper'))
          .toList();
      layers.insert(
          0,
          StudioLayer(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: 'Wallpaper',
              kind: LayerKind.image,
              imagePath: path,
              x: .5,
              y: .5,
              width: 1,
              height: 1));
      doc = doc.copyWith(layers: layers);
      selectedId = doc.layers.first.id;
    });
  }

  Future<void> _pickFont() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        withData: false);
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/fonts');
    await dir.create(recursive: true);
    final family = 'Imported${DateTime.now().millisecondsSinceEpoch}';
    final path = '${dir.path}/$family.${file.extension ?? 'ttf'}';
    final fontFile = File(file.path!);
    final bytes = await fontFile.readAsBytes();
    await fontFile.copy(path);
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
    _loadedFonts.add(family);
    if (selected != null) {
      _mutate(() => _updateLayer(
          selected!.id, (layer) => layer.copyWith(fontFamily: family)));
    }
  }

  Future<void> _loadFonts(StudioDocument document) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/fonts');
    if (!await directory.exists()) return;
    final families = document.layers
        .map((layer) => layer.fontFamily)
        .whereType<String>()
        .where((family) =>
            family.startsWith('Imported') && !_loadedFonts.contains(family))
        .toSet();
    for (final family in families) {
      final candidates = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.uri.pathSegments.last.startsWith('$family.'));
      if (candidates.isEmpty) continue;
      final bytes = await candidates.first.readAsBytes();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFonts.add(family);
    }
  }

  Future<void> _export() async {
    setState(() => _showSelection = false);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image =
          await boundary.toImage(pixelRatio: doc.width / boundary.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('Could not render composition');
      final root = await getApplicationDocumentsDirectory();
      final outDir = Directory('${root.path}/exports');
      await outDir.create(recursive: true);
      final file = File(
          '${outDir.path}/${DateTime.now().millisecondsSinceEpoch}_wallpaper.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      if (mounted) {
        await showModalBottomSheet<void>(
            context: context,
            backgroundColor: _panel,
            builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Composition exported',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Use as lock screen wallpaper'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await _wallpaper.invokeMethod<void>('setWallpaper',
                                {'path': file.path, 'which': 'lock'});
                            if (mounted) {
                              _notice('Lock screen wallpaper applied');
                            }
                          } on PlatformException catch (e) {
                            if (mounted) {
                              _notice(e.message ?? 'Could not apply wallpaper');
                            }
                          }
                        }),
                    ListTile(
                        leading: const Icon(Icons.phone_android),
                        title: const Text('Use as home screen wallpaper'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await _wallpaper.invokeMethod<void>('setWallpaper',
                                {'path': file.path, 'which': 'home'});
                            if (mounted) {
                              _notice('Home screen wallpaper applied');
                            }
                          } on PlatformException catch (e) {
                            if (mounted) {
                              _notice(e.message ?? 'Could not apply wallpaper');
                            }
                          }
                        }),
                    ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text('Saved to ${file.path.split('/').last}'),
                        onTap: () => Navigator.pop(ctx)),
                  ]),
                ));
      }
    } catch (e) {
      if (mounted) _notice('Export failed: $e');
    }
    if (mounted) setState(() => _showSelection = true);
  }

  Future<void> _preview() async {
    setState(() => _showSelection = false);
    await showDialog<void>(
        context: context,
        builder: (previewContext) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                child: Stack(children: [
                  _PreviewClock(
                      showSeconds: doc.layers.any((layer) =>
                          layer.kind == LayerKind.clock &&
                          layer.showSeconds &&
                          layer.visible),
                      builder: () => Positioned.fill(child: Center(
                              child: LayoutBuilder(builder: (context, bounds) {
                            final ratio = doc.width / doc.height;
                            var width = bounds.maxWidth;
                            var height = width / ratio;
                            if (height > bounds.maxHeight) {
                              height = bounds.maxHeight;
                              width = height * ratio;
                            }
                            return SizedBox(
                                width: width,
                                height: height,
                                child: IgnorePointer(
                                    child: _canvas(width, height)));
                          })))),
                  Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                          onPressed: () => Navigator.pop(previewContext),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close preview')),
                ]),
              ),
            ));
    if (mounted) setState(() => _showSelection = true);
  }

  void _notice(String text) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> _addLayer(LayerKind kind) async {
    if (kind == LayerKind.image) {
      await _pickWallpaper();
      return;
    }
    final layer = StudioLayer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kind: kind,
        name: kind == LayerKind.clock
            ? 'Clock'
            : kind == LayerKind.date
                ? 'Date'
                : 'Text',
        text: kind == LayerKind.text ? 'Your text' : '',
        x: .5,
        y: .42,
        width: .78,
        height: kind == LayerKind.clock ? .32 : .08,
        fontSize: kind == LayerKind.clock ? 260 : 64,
        color: 0xffffffff);
    _mutate(() {
      doc = doc.copyWith(layers: [...doc.layers, layer]);
      selectedId = layer.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final layer = selected;
    return Scaffold(
        body: SafeArea(
            child: Column(children: [
      _topBar(),
      Expanded(child: LayoutBuilder(builder: (context, bounds) {
        final ratio = doc.width / doc.height;
        var w = bounds.maxWidth;
        var h = w / ratio;
        if (h > bounds.maxHeight) {
          h = bounds.maxHeight;
          w = h * ratio;
        }
        return Center(
            child: SizedBox(
                width: w,
                height: h,
                child: RepaintBoundary(key: _canvasKey, child: _canvas(w, h))));
      })),
      _bottomBar(),
      if (layer != null) _propertyPanel(layer),
    ])));
  }

  Widget _topBar() => Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
      child: Row(children: [
        IconButton(
            onPressed: () => _openProjects(),
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Open project'),
        const SizedBox(width: 4),
        Expanded(
            child: GestureDetector(
                onTap: _renameProject,
                child: Text(doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 17)))),
        IconButton(
            onPressed: _undoAction,
            icon: Icon(Icons.undo,
                color: _undo.isEmpty ? Colors.white30 : Colors.white),
            tooltip: 'Undo'),
        IconButton(
            onPressed: _redoAction,
            icon: Icon(Icons.redo,
                color: _redo.isEmpty ? Colors.white30 : Colors.white),
            tooltip: 'Redo'),
        IconButton(
            onPressed: _preview,
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Preview'),
        IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save'),
        IconButton(
            onPressed: _export,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export'),
      ]));

  Widget _canvas(double w, double h) => ClipRRect(
      borderRadius: BorderRadius.circular(27),
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
              Color(0xff2c1517),
              Color(0xffbd2414),
              Color(0xff3a0907),
              Color(0xff150807)
            ],
                        stops: [
              0,
              .48,
              .67,
              1
            ])))),
        ...doc.layers.asMap().entries.map((e) => _layerWidget(e.value, w, h)),
        if (doc.layers
            .where((l) => l.kind == LayerKind.image && l.imagePath != null)
            .isEmpty)
          Positioned(
              left: 0,
              right: 0,
              top: h * .55,
              height: h * .15,
              child: IgnorePointer(child: CustomPaint(painter: _CarPainter()))),
      ]));

  Widget _layerWidget(StudioLayer l, double w, double h) {
    if (!l.visible) return const SizedBox.shrink();
    final boxW = w * l.width, boxH = h * l.height;
    final isSelected = _showSelection && selectedId == l.id;
    final Widget content;
    if (l.kind == LayerKind.image) {
      final f = l.imagePath == null ? null : File(l.imagePath!);
      content = f != null && f.existsSync()
          ? Opacity(
              opacity: l.opacity,
              child: Image.file(f,
                  fit: BoxFit.cover,
                  cacheWidth: doc.width,
                  errorBuilder: (_, __, ___) => const SizedBox()))
          : const SizedBox();
    } else {
      final text = switch (l.kind) {
        LayerKind.clock => _clockText(l),
        LayerKind.date =>
          DateFormat(l.text.isEmpty ? 'EEE, d MMM yyyy' : l.text)
              .format(DateTime.now()),
        LayerKind.text => l.text,
        LayerKind.image => '',
      };
      content = Opacity(
          opacity: l.opacity,
          child: Center(
              child: FittedBox(
                  fit: BoxFit.fill,
                  child: Text(text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(l.color),
                          fontSize: l.fontSize * w / doc.width,
                          fontFamily: l.fontFamily,
                          letterSpacing: l.letterSpacing * w / doc.width,
                          height: l.kind == LayerKind.clock ? .78 : 1,
                          fontWeight: l.kind == LayerKind.clock
                              ? FontWeight.w300
                              : FontWeight.w500)))));
    }
    return Positioned(
        left: w * l.x - boxW / 2,
        top: h * l.y - boxH / 2,
        width: boxW,
        height: boxH,
        child: Transform.rotate(
            angle: l.rotation,
            child: Transform.scale(
                scaleX: l.scaleX,
                scaleY: l.scaleY,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  key: ValueKey('layer-${l.id}'),
                  onTap: () => setState(() => selectedId = l.id),
                  onScaleStart: (_) {
                    setState(() => selectedId = l.id);
                    _pinchScale[l.id] = 1;
                    _pinchRotation[l.id] = 0;
                    _checkpoint();
                  },
                  onScaleUpdate: (d) {
                    if (l.locked) return;
                    setState(() {
                      var updated = doc.layers.firstWhere(
                          (layer) => layer.id == l.id,
                          orElse: () => l);
                      updated = TransformEngine.move(updated,
                          d.focalPointDelta.dx, d.focalPointDelta.dy, w, h);
                      if (d.pointerCount > 1) {
                        final previous = _pinchScale[l.id] ?? 1;
                        final incremental = d.scale / previous;
                        updated = TransformEngine.scale(
                            updated, incremental, incremental);
                        _pinchScale[l.id] = d.scale;
                        final previousRotation = _pinchRotation[l.id] ?? 0;
                        updated = TransformEngine.rotate(
                            updated, d.rotation - previousRotation);
                        _pinchRotation[l.id] = d.rotation;
                      }
                      _replaceLayer(updated);
                    });
                  },
                  onScaleEnd: (_) {
                    _pinchScale.remove(l.id);
                    _pinchRotation.remove(l.id);
                  },
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(child: content),
                    if (isSelected)
                      Positioned.fill(
                          child: IgnorePointer(
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: _accent.withValues(alpha: .85),
                                          width: 1.2))))),
                  ]),
                ))));
  }

  String _clockText(StudioLayer l) {
    final now = DateTime.now();
    var hours =
        l.use24Hour ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
    final separator = l.verticalClock ? '\n' : ':';
    final time = '${hours.toString().padLeft(2, '0')}$separator'
        '${now.minute.toString().padLeft(2, '0')}'
        '${l.showSeconds ? '${l.verticalClock ? '\n' : ':'}${now.second.toString().padLeft(2, '0')}' : ''}'
        '${l.use24Hour ? '' : '${l.verticalClock ? '\n' : ' '}${now.hour < 12 ? 'AM' : 'PM'}'}';
    return time;
  }

  Widget _bottomBar() => Container(
      height: 62,
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _tool('Add', Icons.add, () => _showAddMenu()),
        _tool('Layers', Icons.layers_outlined, _showLayers),
        _tool('Typography', Icons.text_fields,
            () => setState(() => _activeTool = 'Typography')),
        _tool('Transform', Icons.open_with,
            () => setState(() => _activeTool = 'Transform')),
        _tool('Appearance', Icons.palette_outlined,
            () => setState(() => _activeTool = 'Appearance')),
      ]));

  Widget _tool(String name, IconData icon, VoidCallback action) => InkWell(
      onTap: action,
      child: SizedBox(
          width: 70,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 21,
                color: _activeTool == name ? _accent : Colors.white70),
            const SizedBox(height: 4),
            Text(name,
                style: TextStyle(
                    fontSize: 10,
                    color: _activeTool == name ? _accent : Colors.white70)),
          ])));

  Future<void> _showAddMenu() async {
    await showModalBottomSheet<void>(
        context: context,
        backgroundColor: _panel,
        builder: (ctx) => SafeArea(
                child: Wrap(children: [
              const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 16, 8),
                  child: Text('Add to canvas',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Wallpaper image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickWallpaper();
                  }),
              ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Live clock'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addLayer(LayerKind.clock);
                  }),
              ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Date'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addLayer(LayerKind.date);
                  }),
              ListTile(
                  leading: const Icon(Icons.title),
                  title: const Text('Text'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addLayer(LayerKind.text);
                  }),
            ])));
  }

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
        context: context,
        backgroundColor: _panel,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, refresh) => SafeArea(
                  child: SizedBox(
                      height: MediaQuery.sizeOf(ctx).height * .62,
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(children: [
                              const Expanded(
                                  child: Text('Layers',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold))),
                              IconButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAddMenu();
                                  },
                                  icon: const Icon(Icons.add))
                            ])),
                        Expanded(
                            child: ReorderableListView.builder(
                                itemCount: doc.layers.length,
                                onReorder: (a, b) {
                                  _checkpoint();
                                  setState(() {
                                    if (b > a) b--;
                                    final layers = [...doc.layers];
                                    final it = layers.removeAt(a);
                                    layers.insert(b, it);
                                    doc = doc.copyWith(layers: layers);
                                  });
                                  refresh(() {});
                                },
                                itemBuilder: (context, i) {
                                  final l = doc.layers[i];
                                  return ListTile(
                                      key: ValueKey(l.id),
                                      selected: selectedId == l.id,
                                      leading: Icon(l.kind == LayerKind.clock
                                          ? Icons.schedule
                                          : l.kind == LayerKind.image
                                              ? Icons.image_outlined
                                              : Icons.text_fields),
                                      title: Text(l.name),
                                      subtitle: Text(l.kind.name),
                                      onTap: () {
                                        setState(() => selectedId = l.id);
                                        Navigator.pop(ctx);
                                      },
                                      trailing: Wrap(spacing: 2, children: [
                                        IconButton(
                                            icon: Icon(
                                                l.visible
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined,
                                                size: 19),
                                            onPressed: () {
                                              _mutate(() => _updateLayer(
                                                  l.id,
                                                  (layer) => layer.copyWith(
                                                      visible:
                                                          !layer.visible)));
                                              refresh(() {});
                                            }),
                                        IconButton(
                                            icon: Icon(
                                                l.locked
                                                    ? Icons.lock_outline
                                                    : Icons.lock_open_outlined,
                                                size: 19),
                                            onPressed: () {
                                              _mutate(() => _updateLayer(
                                                  l.id,
                                                  (layer) => layer.copyWith(
                                                      locked: !layer.locked)));
                                              refresh(() {});
                                            }),
                                        IconButton(
                                            icon: const Icon(Icons.copy,
                                                size: 19),
                                            onPressed: () {
                                              _mutate(() {
                                                final layers = [...doc.layers];
                                                layers.insert(
                                                    i + 1,
                                                    l.copyWith(
                                                        id: DateTime.now()
                                                            .microsecondsSinceEpoch
                                                            .toString(),
                                                        name:
                                                            '${l.name} copy'));
                                                doc = doc.copyWith(
                                                    layers: layers);
                                              });
                                              refresh(() {});
                                            }),
                                        IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 19),
                                            onPressed: () {
                                              _mutate(() {
                                                doc = doc.copyWith(
                                                    layers: doc.layers
                                                        .where((layer) =>
                                                            layer.id != l.id)
                                                        .toList());
                                                if (selectedId == l.id) {
                                                  selectedId = null;
                                                }
                                              });
                                              refresh(() {});
                                            }),
                                      ]));
                                })),
                      ])),
                )));
  }

  Widget _propertyPanel(StudioLayer layer) {
    final isType = layer.kind != LayerKind.image;
    return Container(
        color: _panel,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: Text(
                    _activeTool == 'Typography'
                        ? 'TYPE  ·  ${layer.name.toUpperCase()}'
                        : _activeTool == 'Appearance'
                            ? 'APPEARANCE  ·  ${layer.name.toUpperCase()}'
                            : 'TRANSFORM  ·  ${layer.name.toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: Colors.white60))),
            if (layer.kind == LayerKind.clock)
              TextButton(
                  onPressed: () => _mutate(() => _updateLayer(
                      layer.id,
                      (current) =>
                          current.copyWith(use24Hour: !current.use24Hour))),
                  child: Text(layer.use24Hour ? '24 H' : '12 H')),
            if (layer.kind == LayerKind.clock)
              IconButton(
                  onPressed: () => _mutate(() => _updateLayer(
                      layer.id,
                      (current) =>
                          current.copyWith(showSeconds: !current.showSeconds))),
                  icon: Icon(Icons.more_time,
                      color: layer.showSeconds ? _accent : Colors.white54)),
            if (layer.kind == LayerKind.clock)
              TextButton(
                  onPressed: () => _mutate(() => _updateLayer(
                      layer.id,
                      (current) => current.copyWith(
                          verticalClock: !current.verticalClock))),
                  child: Text(layer.verticalClock ? 'VERT' : 'HORIZ')),
            IconButton(
                onPressed: () => _mutate(() {
                      doc = doc.copyWith(layers: [
                        ...doc.layers,
                        layer.copyWith(
                            id: DateTime.now()
                                .microsecondsSinceEpoch
                                .toString(),
                            name: '${layer.name} copy'),
                      ]);
                    }),
                icon: const Icon(Icons.copy, size: 18)),
            IconButton(
                onPressed: () => _mutate(() {
                      doc = doc.copyWith(
                          layers: doc.layers
                              .where((item) => item.id != layer.id)
                              .toList());
                      selectedId = null;
                    }),
                icon: const Icon(Icons.delete_outline, size: 18)),
          ]),
          if (_activeTool == 'Typography' && isType) ...[
            Row(children: [
              const SizedBox(
                  width: 42,
                  child: Text('Size', style: TextStyle(fontSize: 12))),
              Expanded(
                  child: Slider(
                      key: const ValueKey('font-size-slider'),
                      value: layer.fontSize.clamp(20, 480),
                      min: 20,
                      max: 480,
                      onChanged: (v) => setState(() => _updateLayer(layer.id,
                          (current) => current.copyWith(fontSize: v))),
                      onChangeStart: (_) => _checkpoint())),
              Text(layer.fontSize.round().toString(),
                  style: const TextStyle(fontSize: 11))
            ]),
            Row(children: [
              OutlinedButton.icon(
                  onPressed: _pickFont,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(layer.fontFamily ?? 'Import font',
                      style: const TextStyle(fontSize: 11))),
              if (layer.kind == LayerKind.date)
                Expanded(
                    child: TextButton(
                        onPressed: () => _editDateFormat(layer),
                        child: Text(
                            layer.text.isEmpty ? 'EEE, d MMM yyyy' : layer.text,
                            overflow: TextOverflow.ellipsis))),
              if (layer.kind == LayerKind.text)
                Expanded(
                    child: TextButton(
                        onPressed: () => _editText(layer),
                        child:
                            Text(layer.text, overflow: TextOverflow.ellipsis))),
            ]),
            Row(children: [
              const SizedBox(
                  width: 42,
                  child: Text('Spacing', style: TextStyle(fontSize: 12))),
              Expanded(
                  child: Slider(
                      value: layer.letterSpacing.clamp(-20, 80),
                      min: -20,
                      max: 80,
                      onChanged: (v) => setState(() => _updateLayer(layer.id,
                          (current) => current.copyWith(letterSpacing: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
          ] else if (_activeTool == 'Appearance') ...[
            Row(children: [
              const SizedBox(
                  width: 62,
                  child: Text('Opacity', style: TextStyle(fontSize: 12))),
              Expanded(
                  child: Slider(
                      value: layer.opacity,
                      min: .05,
                      max: 1,
                      onChanged: (v) => setState(() => _updateLayer(
                          layer.id, (current) => current.copyWith(opacity: v))),
                      onChangeStart: (_) => _checkpoint())),
              Text('${(layer.opacity * 100).round()}%',
                  style: const TextStyle(fontSize: 11))
            ]),
            if (isType)
              Row(children: [
                const Text('Color', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 10),
                ...[
                  0xfff7f2ee,
                  0xffffdf47,
                  0xffc5ff60,
                  0xff8ddcff,
                  0xffff6c9b,
                  0xff171717
                ].map((c) => InkWell(
                    onTap: () => _mutate(() => _updateLayer(
                        layer.id, (current) => current.copyWith(color: c))),
                    child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: layer.color == c
                                    ? _accent
                                    : Colors.white24))))),
                const Spacer(),
                TextButton(onPressed: _editColor, child: const Text('Custom'))
              ]),
          ] else ...[
            Row(children: [
              const SizedBox(
                  width: 64,
                  child: Text('Width', style: TextStyle(fontSize: 11))),
              Expanded(
                  child: Slider(
                      key: const ValueKey('width-slider'),
                      value: layer.width.clamp(.015, 4),
                      min: .015,
                      max: 4,
                      onChanged: (v) => setState(() => _updateLayer(
                          layer.id, (current) => current.copyWith(width: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
            Row(children: [
              const SizedBox(
                  width: 64,
                  child: Text('Height', style: TextStyle(fontSize: 11))),
              Expanded(
                  child: Slider(
                      key: const ValueKey('height-slider'),
                      value: layer.height.clamp(.015, 4),
                      min: .015,
                      max: 4,
                      onChanged: (v) => setState(() => _updateLayer(
                          layer.id, (current) => current.copyWith(height: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
            Row(children: [
              const SizedBox(
                  width: 64,
                  child: Text('Rotation', style: TextStyle(fontSize: 11))),
              Expanded(
                  child: Slider(
                      value: layer.rotation.clamp(-3.14, 3.14),
                      min: -3.14,
                      max: 3.14,
                      onChanged: (v) => setState(() => _updateLayer(layer.id,
                          (current) => current.copyWith(rotation: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
            Row(children: [
              const SizedBox(
                  width: 64,
                  child: Text('Scale X', style: TextStyle(fontSize: 11))),
              Expanded(
                  child: Slider(
                      value: layer.scaleX.clamp(.05, 12),
                      min: .05,
                      max: 12,
                      onChanged: (v) => setState(() => _updateLayer(
                          layer.id, (current) => current.copyWith(scaleX: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
            Row(children: [
              const SizedBox(
                  width: 64,
                  child: Text('Scale Y', style: TextStyle(fontSize: 11))),
              Expanded(
                  child: Slider(
                      value: layer.scaleY.clamp(.05, 12),
                      min: .05,
                      max: 12,
                      onChanged: (v) => setState(() => _updateLayer(
                          layer.id, (current) => current.copyWith(scaleY: v))),
                      onChangeStart: (_) => _checkpoint()))
            ]),
          ],
        ]));
  }

  Future<void> _editText(StudioLayer layer) async {
    final controller = TextEditingController(text: layer.text);
    final v = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Edit text'),
                content: TextField(controller: controller, autofocus: true),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Done'))
                ]));
    if (v != null) {
      _mutate(
          () => _updateLayer(layer.id, (current) => current.copyWith(text: v)));
    }
  }

  Future<void> _editDateFormat(StudioLayer layer) async {
    final controller = TextEditingController(
        text: layer.text.isEmpty ? 'EEE, d MMM yyyy' : layer.text);
    final v = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Date format'),
                content: TextField(
                    controller: controller,
                    decoration:
                        const InputDecoration(hintText: 'EEE, d MMM yyyy')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Done'))
                ]));
    if (v != null) {
      _mutate(() {
        var format = v;
        try {
          DateFormat(format).format(DateTime.now());
        } catch (_) {
          format = 'EEE, d MMM yyyy';
        }
        _updateLayer(layer.id, (current) => current.copyWith(text: format));
      });
    }
  }

  Future<void> _editColor() async {
    final controller = TextEditingController(
        text:
            '#${selected!.color.toRadixString(16).padLeft(8, '0').substring(2)}');
    final v = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Hex color'),
                content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: '#ffffff')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, controller.text),
                      child: const Text('Apply'))
                ]));
    if (v == null) return;
    try {
      final n = int.parse(v.replaceAll('#', ''), radix: 16);
      final selectedId = selected?.id;
      if (selectedId != null) {
        _mutate(() => _updateLayer(
            selectedId, (layer) => layer.copyWith(color: 0xff000000 | n)));
      }
    } catch (_) {
      _notice('Enter a six digit hex color');
    }
  }
}

class _PreviewClock extends StatefulWidget {
  const _PreviewClock({required this.showSeconds, required this.builder});

  final bool showSeconds;
  final Widget Function() builder;

  @override
  State<_PreviewClock> createState() => _PreviewClockState();
}

class _PreviewClockState extends State<_PreviewClock> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.showSeconds || DateTime.now().second == 0) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder();
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xff09090b).withValues(alpha: .94);
    final path = Path()
      ..moveTo(size.width * .08, size.height * .70)
      ..lineTo(size.width * .15, size.height * .62)
      ..lineTo(size.width * .25, size.height * .58)
      ..lineTo(size.width * .37, size.height * .33)
      ..quadraticBezierTo(size.width * .43, size.height * .19, size.width * .56,
          size.height * .27)
      ..lineTo(size.width * .78, size.height * .55)
      ..lineTo(size.width * .90, size.height * .62)
      ..lineTo(size.width * .94, size.height * .70)
      ..lineTo(size.width * .92, size.height * .85)
      ..lineTo(size.width * .10, size.height * .85)
      ..close();
    canvas.drawPath(path, p);
    final wheel = Paint()..color = const Color(0xff19191b);
    canvas.drawCircle(
        Offset(size.width * .28, size.height * .79), size.height * .14, wheel);
    canvas.drawCircle(
        Offset(size.width * .75, size.height * .79), size.height * .14, wheel);
    final glass = Paint()..color = const Color(0xff422e32);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .39, size.height * .35)
          ..quadraticBezierTo(size.width * .45, size.height * .25,
              size.width * .53, size.height * .31)
          ..lineTo(size.width * .66, size.height * .54)
          ..lineTo(size.width * .31, size.height * .54)
          ..close(),
        glass);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
