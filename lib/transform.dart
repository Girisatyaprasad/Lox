import 'document.dart';

/// Gesture deltas are expressed in stage pixels; document positions and sizes
/// are normalized to the stage, so projects remain resolution independent.
class LayerTransform {
  static void move(StudioLayer layer, double dx, double dy, double stageWidth,
      double stageHeight) {
    if (layer.locked) return;
    layer.x += dx / stageWidth;
    layer.y += dy / stageHeight;
  }

  static void resize(StudioLayer layer, double dx, double dy, double stageWidth,
      double stageHeight) {
    if (layer.locked) return;
    layer.width = (layer.width + dx / stageWidth).clamp(.015, 4).toDouble();
    layer.height = (layer.height + dy / stageHeight).clamp(.015, 4).toDouble();
  }

  static void scale(StudioLayer layer, double sx, double sy) {
    if (layer.locked) return;
    layer.scaleX = (layer.scaleX * sx).clamp(.05, 12).toDouble();
    layer.scaleY = (layer.scaleY * sy).clamp(.05, 12).toDouble();
  }
}
