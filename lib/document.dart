import 'dart:convert';

enum LayerKind { clock, date, text, image }

class StudioLayer {
  StudioLayer({
    required this.id,
    required this.name,
    required this.kind,
    this.text = '',
    this.imagePath,
    this.x = .5,
    this.y = .35,
    this.width = .8,
    this.height = .18,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.color = 0xffffffff,
    this.fontFamily,
    this.fontSize = 96,
    this.letterSpacing = 0,
    this.visible = true,
    this.locked = false,
    this.use24Hour = true,
    this.showSeconds = false,
    this.verticalClock = true,
  });

  final String id;
  String name;
  LayerKind kind;
  String text;
  String? imagePath;
  double x, y, width, height, rotation, scaleX, scaleY, opacity;
  int color;
  String? fontFamily;
  double fontSize, letterSpacing;
  bool visible, locked, use24Hour, showSeconds;
  bool verticalClock;

  StudioLayer copy() => StudioLayer.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'text': text,
        'imagePath': imagePath,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'rotation': rotation,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'opacity': opacity,
        'color': color,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'letterSpacing': letterSpacing,
        'visible': visible,
        'locked': locked,
        'use24Hour': use24Hour,
        'showSeconds': showSeconds,
        'verticalClock': verticalClock,
      };

  factory StudioLayer.fromJson(Map<String, dynamic> j) => StudioLayer(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Layer',
        kind: LayerKind.values.byName(j['kind'] as String? ?? 'text'),
        text: j['text'] as String? ?? '',
        imagePath: j['imagePath'] as String?,
        x: (j['x'] as num?)?.toDouble() ?? .5,
        y: (j['y'] as num?)?.toDouble() ?? .5,
        width: (j['width'] as num?)?.toDouble() ?? .5,
        height: (j['height'] as num?)?.toDouble() ?? .1,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
        scaleX: (j['scaleX'] as num?)?.toDouble() ?? 1,
        scaleY: (j['scaleY'] as num?)?.toDouble() ?? 1,
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
        color: (j['color'] as num?)?.toInt() ?? 0xffffffff,
        fontFamily: j['fontFamily'] as String?,
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 96,
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
        visible: j['visible'] as bool? ?? true,
        locked: j['locked'] as bool? ?? false,
        use24Hour: j['use24Hour'] as bool? ?? true,
        showSeconds: j['showSeconds'] as bool? ?? false,
        verticalClock: j['verticalClock'] as bool? ?? true,
      );
}

class StudioDocument {
  StudioDocument(
      {this.title = 'Untitled design',
      this.width = 1080,
      this.height = 2400,
      List<StudioLayer>? layers})
      : layers = layers ?? [];

  String title;
  final int width, height;
  List<StudioLayer> layers;

  StudioDocument copy() => StudioDocument.fromJson(toJson());
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'title': title,
        'width': width,
        'height': height,
        'layers': layers.map((e) => e.toJson()).toList(),
      };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
  factory StudioDocument.fromJson(Map<String, dynamic> j) => StudioDocument(
      title: j['title'] as String? ?? 'Untitled design',
      width: (j['width'] as num?)?.toInt() ?? 1080,
      height: (j['height'] as num?)?.toInt() ?? 2400,
      layers: (j['layers'] as List<dynamic>? ?? [])
          .map((e) => StudioLayer.fromJson(e as Map<String, dynamic>))
          .toList());
  static StudioDocument decode(String source) =>
      StudioDocument.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
