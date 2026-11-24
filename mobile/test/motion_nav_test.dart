import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/ui/motion_nav.dart';

void main() {
  testWidgets('Navigation stays readable at 320px with 200% text', (t) async {
    t.view.physicalSize = const Size(320, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(true),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ValueListenableBuilder<int>(
            valueListenable: index,
            builder: (_, value, _) => Scaffold(
              bottomNavigationBar: MotionNav(
                index: value,
                onSelect: (i) => index.value = i,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      final control = find.byKey(ValueKey('nav-$i'));
      await t.tap(control);
      await t.pumpAndSettle();
      final rect = t.getRect(control);
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(t.takeException(), isNull);
    }
    for (final name in ['Asosiy', 'Lug‘at', 'O‘yin', 'Profil']) {
      expect(find.text(name), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is Tooltip && w.message == name),
        findsOneWidget,
      );
    }
    index.value = 0;
    await t.pumpAndSettle();
    await t.drag(find.byKey(const ValueKey('nav-0')), const Offset(204, 0));
    await t.pumpAndSettle();
    expect(index.value, 3);
    expect(
      t.binding.transientCallbackCount,
      0,
      reason: 'Settled navigation must not keep an animation clock running',
    );
  });
}
