import '../../core/domain/studio_layer.dart';

/// Pure transformation operations for normalized document layers.
class TransformEngine {
  const TransformEngine._();

  static StudioLayer move(
    StudioLayer layer,
    double dx,
    double dy,
    double stageWidth,
    double stageHeight,
  ) {
    if (layer.locked) return layer;
    return layer.copyWith(
      x: layer.x + dx / stageWidth,
      y: layer.y + dy / stageHeight,
    );
  }

  static StudioLayer resize(
    StudioLayer layer,
    double dx,
    double dy,
    double stageWidth,
    double stageHeight,
  ) {
    if (layer.locked) return layer;
    return layer.copyWith(
      width: (layer.width + dx / stageWidth).clamp(.015, 4).toDouble(),
      height: (layer.height + dy / stageHeight).clamp(.015, 4).toDouble(),
    );
  }

  static StudioLayer scale(StudioLayer layer, double sx, double sy) {
    if (layer.locked) return layer;
    return layer.copyWith(
      scaleX: (layer.scaleX * sx).clamp(.05, 12).toDouble(),
      scaleY: (layer.scaleY * sy).clamp(.05, 12).toDouble(),
    );
  }

  static StudioLayer rotate(StudioLayer layer, double deltaRadians) {
    if (layer.locked) return layer;
    return layer.copyWith(rotation: layer.rotation + deltaRadians);
  }
}
