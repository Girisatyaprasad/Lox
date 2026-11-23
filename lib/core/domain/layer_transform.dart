/// Normalized position and independent size/scale values for a canvas layer.
///
/// Coordinates and dimensions are relative to the document stage. Rotation is
/// in radians; scale values are independent multipliers applied to the layer.
class LayerTransform {
  const LayerTransform({
    this.x = .5,
    this.y = .35,
    this.width = .8,
    this.height = .18,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double scaleX;
  final double scaleY;

  LayerTransform copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
  }) =>
      LayerTransform(
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerTransform &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height &&
          rotation == other.rotation &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY;

  @override
  int get hashCode =>
      Object.hash(x, y, width, height, rotation, scaleX, scaleY);
}
