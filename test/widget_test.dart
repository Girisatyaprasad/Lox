import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeform_lockstudio/main.dart';

void main() {
  testWidgets('editor shows the live clock and essential editing tools',
      (tester) async {
    await tester.pumpWidget(const LockStudioApp());
    final clock = find.byKey(const ValueKey('layer-clock'));
    expect(clock, findsOneWidget);
    expect(find.text('Layers'), findsOneWidget);
    expect(find.text('Typography'), findsOneWidget);
    expect(find.text('Transform'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    final beforeMove = tester.getRect(clock);
    await tester.drag(clock, const Offset(32, 42));
    await tester.pump();
    final afterMove = tester.getRect(clock);
    expect(afterMove.center.dx, greaterThan(beforeMove.center.dx + 10));
    expect(afterMove.center.dy, greaterThan(beforeMove.center.dy + 10));
    final widthSlider = find.byKey(const ValueKey('width-slider'));
    final widthBefore = tester.widget<Slider>(widthSlider).value;
    final sliderRect = tester.getRect(widthSlider);
    await tester.tapAt(Offset(sliderRect.right - 4, sliderRect.center.dy));
    await tester.pump();
    expect(tester.widget<Slider>(widthSlider).value, greaterThan(widthBefore));
    final widthAfter = tester.widget<Slider>(widthSlider).value;
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(tester.widget<Slider>(widthSlider).value, closeTo(widthBefore, .01));
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(tester.widget<Slider>(widthSlider).value, closeTo(widthAfter, .01));
    await tester.tap(find.text('Typography'));
    await tester.pump();
    expect(find.byKey(const ValueKey('font-size-slider')), findsOneWidget);
  });
}
