import 'studio_layer.dart';

/// Immutable editable project document.
class StudioDocument {
  StudioDocument({
    this.title = 'Untitled design',
    this.width = 1080,
    this.height = 2400,
    List<StudioLayer>? layers,
  }) : layers = List.unmodifiable(layers ?? const <StudioLayer>[]);

  final String title;
  final int width;
  final int height;
  final List<StudioLayer> layers;

  StudioDocument copyWith({
    String? title,
    int? width,
    int? height,
    List<StudioLayer>? layers,
  }) =>
      StudioDocument(
        title: title ?? this.title,
        width: width ?? this.width,
        height: height ?? this.height,
        layers: layers ?? this.layers,
      );

  /// Documents and their layers are immutable, so history can share a snapshot.
  StudioDocument copy() => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StudioDocument ||
        title != other.title ||
        width != other.width ||
        height != other.height ||
        layers.length != other.layers.length) {
      return false;
    }
    for (var i = 0; i < layers.length; i++) {
      if (layers[i] != other.layers[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(title, width, height, Object.hashAll(layers));
}
