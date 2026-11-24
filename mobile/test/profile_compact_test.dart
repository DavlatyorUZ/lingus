import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/account_api.dart';
import 'package:lingoy/screens/account.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  testWidgets('Signed-in profile actions fit 320px at normal and double text', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    accountApi.user = {
      'id': 'profile-layout',
      'name': 'Muhammadali Abdurahmonov',
      'email': 'very.long.profile.address@example.com',
      'hasPassword': true,
    };
    addTearDown(() => accountApi.user = null);
    for (final scale in [1.0, 2.0]) {
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 700),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(18),
                child: AccountCard(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Qurilmadagi so‘zlarni ko‘chirish').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Parolni almashtirish').hitTestable(), findsOneWidget);
      expect(find.text('Akkauntdan chiqish').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });
}
