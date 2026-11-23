import 'package:flutter_test/flutter_test.dart';
import 'package:freeform_lockstudio/core/domain/layer_transform.dart';
import 'package:freeform_lockstudio/core/domain/studio_document.dart';
import 'package:freeform_lockstudio/core/domain/studio_layer.dart';
import 'package:freeform_lockstudio/features/editor/domain/transform_engine.dart';
import 'package:freeform_lockstudio/features/projects/data/serialization/document_codec.dart';

void main() {
  test('legacy version 1 JSON round trip preserves every field meaning', () {
    const legacyJson = '''
{
  "schemaVersion": 1,
  "title": "Tall clock",
  "width": 1080,
  "height": 2400,
  "layers": [
    {
      "id": "clock-1",
      "name": "Clock",
      "kind": "clock",
      "text": "",
      "imagePath": "/app/documents/assets/wallpaper.png",
      "x": 0.37,
      "y": 0.41,
      "width": 0.24,
      "height": 0.7,
      "rotation": 0.2,
      "scaleX": 0.8,
      "scaleY": 1.4,
      "opacity": 0.73,
      "color": 4289379276,
      "fontFamily": "ImportedFont",
      "fontSize": 220.0,
      "letterSpacing": 2.5,
      "visible": true,
      "locked": false,
      "use24Hour": false,
      "showSeconds": true,
      "verticalClock": false
    }
  ]
}
''';
    final document = DocumentCodec.decode(legacyJson);
    final layer = document.layers.single;

    expect(document.title, 'Tall clock');
    expect(document.width, 1080);
    expect(document.height, 2400);
    expect(layer.kind, LayerKind.clock);
    expect(layer.imagePath, '/app/documents/assets/wallpaper.png');
    expect(layer.transform, const LayerTransform(
      x: .37,
      y: .41,
      width: .24,
      height: .7,
      rotation: .2,
      scaleX: .8,
      scaleY: 1.4,
    ));
    expect(layer.opacity, .73);
    expect(layer.color, 4289379276);
    expect(layer.fontFamily, 'ImportedFont');
    expect(layer.fontSize, 220);
    expect(layer.letterSpacing, 2.5);
    expect(layer.use24Hour, isFalse);
    expect(layer.showSeconds, isTrue);
    expect(layer.verticalClock, isFalse);

    // Verify the codec emits the same established version and property names.
    final encoded = DocumentCodec.toJson(document);
    expect(encoded['schemaVersion'], 1);
    final encodedLayer = (encoded['layers'] as List).single as Map;
    expect(encodedLayer.keys, [
      'id',
      'name',
      'kind',
      'text',
      'imagePath',
      'x',
      'y',
      'width',
      'height',
      'rotation',
      'scaleX',
      'scaleY',
      'opacity',
      'color',
      'fontFamily',
      'fontSize',
      'letterSpacing',
      'visible',
      'locked',
      'use24Hour',
      'showSeconds',
      'verticalClock',
    ]);
    expect(DocumentCodec.decode(DocumentCodec.encode(document)), document);
  });

  test('codec retains legacy defaults when optional fields are absent', () {
    final document = DocumentCodec.fromJson({
      'layers': [
        {'id': 'legacy-layer'}
      ]
    });
    final layer = document.layers.single;
    expect(document.title, 'Untitled design');
    expect(document.width, 1080);
    expect(document.height, 2400);
    expect(layer.kind, LayerKind.text);
    expect(layer.x, .5);
    expect(layer.y, .5);
    expect(layer.width, .5);
    expect(layer.height, .1);
    expect(layer.color, 0xffffffff);
    expect(layer.visible, isTrue);
  });

  test('copyWith creates value updates without mutating the original', () {
    final original = StudioLayer(
      id: 'a',
      name: 'A',
      kind: LayerKind.text,
      imagePath: '/image.png',
      fontFamily: 'ImportedFont',
    );
    final updated = original.copyWith(
      x: .7,
      opacity: .6,
      imagePath: null,
      clearFontFamily: true,
    );
    expect(original.x, .5);
    expect(original.opacity, 1);
    expect(original.imagePath, '/image.png');
    expect(original.fontFamily, 'ImportedFont');
    expect(updated.x, .7);
    expect(updated.opacity, .6);
    expect(updated.imagePath, isNull);
    expect(updated.fontFamily, isNull);
    expect(() => StudioDocument(layers: [original]).layers.clear(),
        throwsUnsupportedError);
  });

  test('move and resize use independent normalized axes', () {
    final layer = StudioLayer(
      id: 'a',
      name: 'A',
      kind: LayerKind.text,
      x: .5,
      y: .5,
      width: .2,
      height: .3,
    );
    final moved = TransformEngine.move(layer, 40, 100, 400, 1000);
    final resized = TransformEngine.resize(moved, 80, 50, 400, 1000);
    expect(layer.x, .5);
    expect(moved.x, closeTo(.6, 1e-9));
    expect(moved.y, closeTo(.6, 1e-9));
    expect(resized.width, closeTo(.4, 1e-9));
    expect(resized.height, closeTo(.35, 1e-9));
  });

  test('resize and scale preserve established limits and independent axes', () {
    final layer = StudioLayer(
      id: 'scale',
      name: 'Scale',
      kind: LayerKind.text,
      scaleX: .8,
      scaleY: 1.2,
    );
    final scaled = TransformEngine.scale(layer, 1.5, .5);
    final bounded = TransformEngine.resize(scaled, -400, 20000, 400, 1000);
    expect(scaled.scaleX, closeTo(1.2, 1e-9));
    expect(scaled.scaleY, closeTo(.6, 1e-9));
    expect(bounded.width, .015);
    expect(bounded.height, 4);
  });

  test('locked layer ignores move, resize, scale, and rotation', () {
    final layer = StudioLayer(
      id: 'locked',
      name: 'Locked',
      kind: LayerKind.text,
      x: .5,
      y: .5,
      width: .2,
      height: .3,
      locked: true,
    );
    expect(TransformEngine.move(layer, 100, 100, 400, 1000), same(layer));
    expect(TransformEngine.resize(layer, 100, 100, 400, 1000), same(layer));
    expect(TransformEngine.scale(layer, 2, 2), same(layer));
    expect(TransformEngine.rotate(layer, 1), same(layer));
    expect(layer.transform, const LayerTransform(
      x: .5,
      y: .5,
      width: .2,
      height: .3,
    ));
  });
}
