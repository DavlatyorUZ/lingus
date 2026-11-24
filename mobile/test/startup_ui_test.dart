import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/main.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  testWidgets(
    'An error arriving after the first frame exposes retry immediately',
    (tester) async {
      store.error = null;
      addTearDown(() => store.error = null);
      await tester.pumpWidget(
        MaterialApp(theme: appTheme(false), home: const LoadingScreen()),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      store.error = 'Lug‘atni tayyorlab bo‘lmadi.';
      store.notifyListeners();
      await tester.pump();
      expect(
        find.widgetWithText(FilledButton, 'Qayta urinish'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      store.error = null;
      store.startupStage = 'Lug‘at fayli tekshirilmoqda…';
      store.notifyListeners();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.textContaining('Lug‘at fayli tekshirilmoqda…'),
        findsOneWidget,
      );
    },
  );
  testWidgets('Startup recovery stays usable at 320px and double text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    store.error = 'Lug‘atni tayyorlab bo‘lmadi. Qayta urinib ko‘ring. Saqlangan so‘zlaringiz o‘chirilmaydi.';
    addTearDown(() => store.error = null);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(false),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: const LoadingScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(FilledButton, 'Qayta urinish');
    await tester.ensureVisible(button);
    expect(button, findsOneWidget);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });
}
