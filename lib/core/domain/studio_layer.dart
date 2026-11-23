import 'layer_transform.dart';

const Object _notProvided = Object();

enum LayerKind { clock, date, text, image }

/// Immutable editable content and appearance for one canvas layer.
class StudioLayer {
  StudioLayer({
    required this.id,
    required this.name,
    required this.kind,
    this.text = '',
    this.imagePath,
    double x = .5,
    double y = .35,
    double width = .8,
    double height = .18,
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
    LayerTransform? transform,
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
  }) : transform = transform ??
            LayerTransform(
              x: x,
              y: y,
              width: width,
              height: height,
              rotation: rotation,
              scaleX: scaleX,
              scaleY: scaleY,
            );

  final String id;
  final String name;
  final LayerKind kind;
  final String text;
  /// Kept as an opaque string at the domain boundary for legacy project paths.
  final String? imagePath;
  final LayerTransform transform;
  final double opacity;
  final int color;
  final String? fontFamily;
  final double fontSize;
  final double letterSpacing;
  final bool visible;
  final bool locked;
  final bool use24Hour;
  final bool showSeconds;
  final bool verticalClock;

  // Convenience read access keeps the existing canvas calculations concise;
  // updates go through copyWith and never mutate the value object.
  double get x => transform.x;
  double get y => transform.y;
  double get width => transform.width;
  double get height => transform.height;
  double get rotation => transform.rotation;
  double get scaleX => transform.scaleX;
  double get scaleY => transform.scaleY;

  StudioLayer copyWith({
    String? id,
    String? name,
    LayerKind? kind,
    String? text,
    Object? imagePath = _notProvided,
    String? fontFamily,
    bool clearFontFamily = false,
    LayerTransform? transform,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? opacity,
    int? color,
    double? fontSize,
    double? letterSpacing,
    bool? visible,
    bool? locked,
    bool? use24Hour,
    bool? showSeconds,
    bool? verticalClock,
  }) =>
      StudioLayer(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        imagePath: identical(imagePath, _notProvided)
            ? this.imagePath
            : imagePath as String?,
        transform: (transform ?? this.transform).copyWith(
          x: x,
          y: y,
          width: width,
          height: height,
          rotation: rotation,
          scaleX: scaleX,
          scaleY: scaleY,
        ),
        opacity: opacity ?? this.opacity,
        color: color ?? this.color,
        fontFamily: clearFontFamily ? null : fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        use24Hour: use24Hour ?? this.use24Hour,
        showSeconds: showSeconds ?? this.showSeconds,
        verticalClock: verticalClock ?? this.verticalClock,
      );

  /// Immutable layers can safely be shared by history snapshots.
  StudioLayer copy() => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioLayer &&
          id == other.id &&
          name == other.name &&
          kind == other.kind &&
          text == other.text &&
          imagePath == other.imagePath &&
          transform == other.transform &&
          opacity == other.opacity &&
          color == other.color &&
          fontFamily == other.fontFamily &&
          fontSize == other.fontSize &&
          letterSpacing == other.letterSpacing &&
          visible == other.visible &&
          locked == other.locked &&
          use24Hour == other.use24Hour &&
          showSeconds == other.showSeconds &&
          verticalClock == other.verticalClock;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        kind,
        text,
        imagePath,
        transform,
        opacity,
        color,
        fontFamily,
        fontSize,
        letterSpacing,
        visible,
        locked,
        use24Hour,
        showSeconds,
        verticalClock,
      );
}
