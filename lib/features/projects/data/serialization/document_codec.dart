import 'dart:convert';

import '../../../../core/domain/layer_transform.dart';
import '../../../../core/domain/studio_document.dart';
import '../../../../core/domain/studio_layer.dart';

/// Persistence adapter for the existing version 1 project JSON format.
///
/// Domain entities stay independent from JSON; all compatibility defaults and
/// flattened transform fields are maintained here.
class DocumentCodec {
  const DocumentCodec._();

  static String encode(StudioDocument document) =>
      const JsonEncoder.withIndent('  ').convert(toJson(document));

  static Map<String, dynamic> toJson(StudioDocument document) => {
        'schemaVersion': 1,
        'title': document.title,
        'width': document.width,
        'height': document.height,
        'layers': document.layers.map(_layerToJson).toList(),
      };

  static StudioDocument decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, dynamic>);

  static StudioDocument fromJson(Map<String, dynamic> json) => StudioDocument(
        title: json['title'] as String? ?? 'Untitled design',
        width: (json['width'] as num?)?.toInt() ?? 1080,
        height: (json['height'] as num?)?.toInt() ?? 2400,
        layers: (json['layers'] as List<dynamic>? ?? [])
            .map((value) => _layerFromJson(value as Map<String, dynamic>))
            .toList(),
      );

  static Map<String, dynamic> _layerToJson(StudioLayer layer) => {
        'id': layer.id,
        'name': layer.name,
        'kind': layer.kind.name,
        'text': layer.text,
        'imagePath': layer.imagePath,
        'x': layer.x,
        'y': layer.y,
        'width': layer.width,
        'height': layer.height,
        'rotation': layer.rotation,
        'scaleX': layer.scaleX,
        'scaleY': layer.scaleY,
        'opacity': layer.opacity,
        'color': layer.color,
        'fontFamily': layer.fontFamily,
        'fontSize': layer.fontSize,
        'letterSpacing': layer.letterSpacing,
        'visible': layer.visible,
        'locked': layer.locked,
        'use24Hour': layer.use24Hour,
        'showSeconds': layer.showSeconds,
        'verticalClock': layer.verticalClock,
      };

  static StudioLayer _layerFromJson(Map<String, dynamic> json) => StudioLayer(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Layer',
        kind: LayerKind.values.byName(json['kind'] as String? ?? 'text'),
        text: json['text'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
        transform: LayerTransform(
          x: (json['x'] as num?)?.toDouble() ?? .5,
          y: (json['y'] as num?)?.toDouble() ?? .5,
          width: (json['width'] as num?)?.toDouble() ?? .5,
          height: (json['height'] as num?)?.toDouble() ?? .1,
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
          scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1,
          scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1,
        ),
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        color: (json['color'] as num?)?.toInt() ?? 0xffffffff,
        fontFamily: json['fontFamily'] as String?,
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 96,
        letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
        use24Hour: json['use24Hour'] as bool? ?? true,
        showSeconds: json['showSeconds'] as bool? ?? false,
        verticalClock: json['verticalClock'] as bool? ?? true,
      );
}
