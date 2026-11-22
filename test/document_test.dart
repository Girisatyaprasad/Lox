import 'package:flutter_test/flutter_test.dart';
import 'package:freeform_lockstudio/document.dart';
import 'package:freeform_lockstudio/transform.dart';

void main() {
  test('document round trip retains independent layer transforms', () {
    final doc = StudioDocument(title: 'Tall clock', layers: [
      StudioLayer(
        id: 'clock-1',
        name: 'Clock',
        kind: LayerKind.clock,
        x: .37,
        y: .41,
        width: .24,
        height: .7,
        scaleX: .8,
        scaleY: 1.4,
        rotation: .2,
        opacity: .73,
        color: 0xffaabbcc,
        fontFamily: 'ImportedFont',
        fontSize: 220,
        letterSpacing: 2.5,
        showSeconds: true,
        verticalClock: false,
      )
    ]);
    final restored = StudioDocument.decode(doc.encode());
    final layer = restored.layers.single;
    expect(restored.title, 'Tall clock');
    expect(layer.x, closeTo(.37, 1e-9));
    expect(layer.width, closeTo(.24, 1e-9));
    expect(layer.height, closeTo(.7, 1e-9));
    expect(layer.scaleX, closeTo(.8, 1e-9));
    expect(layer.scaleY, closeTo(1.4, 1e-9));
    expect(layer.rotation, closeTo(.2, 1e-9));
    expect(layer.opacity, closeTo(.73, 1e-9));
    expect(layer.fontFamily, 'ImportedFont');
    expect(layer.showSeconds, isTrue);
    expect(layer.verticalClock, isFalse);
  });

  test('move and resize use independent normalized axes', () {
    final layer = StudioLayer(
        id: 'a',
        name: 'A',
        kind: LayerKind.text,
        x: .5,
        y: .5,
        width: .2,
        height: .3);
    LayerTransform.move(layer, 40, 100, 400, 1000);
    LayerTransform.resize(layer, 80, 50, 400, 1000);
    expect(layer.x, closeTo(.6, 1e-9));
    expect(layer.y, closeTo(.6, 1e-9));
    expect(layer.width, closeTo(.4, 1e-9));
    expect(layer.height, closeTo(.35, 1e-9));
  });

  test('locked layer ignores all gesture transforms', () {
    final layer = StudioLayer(
        id: 'a',
        name: 'A',
        kind: LayerKind.text,
        x: .5,
        y: .5,
        width: .2,
        height: .3,
        locked: true);
    LayerTransform.move(layer, 100, 100, 400, 1000);
    LayerTransform.resize(layer, 100, 100, 400, 1000);
    LayerTransform.scale(layer, 2, 2);
    expect([
      layer.x,
      layer.y,
      layer.width,
      layer.height,
      layer.scaleX,
      layer.scaleY
    ], [
      .5,
      .5,
      .2,
      .3,
      1,
      1
    ]);
  });

  test('scale updates horizontal and vertical scale independently', () {
    final layer = StudioLayer(
        id: 'scale',
        name: 'Scale',
        kind: LayerKind.text,
        scaleX: .8,
        scaleY: 1.2);
    LayerTransform.scale(layer, 1.5, .5);
    expect(layer.scaleX, closeTo(1.2, 1e-9));
    expect(layer.scaleY, closeTo(.6, 1e-9));
  });
}
