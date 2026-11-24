import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/account_api.dart';
import 'package:lingoy/screens/account.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  testWidgets(
    'Google-only accounts set their first password through email verification',
    (tester) async {
      accountApi.user = {
        'id': 'google-test',
        'name': 'Ali',
        'email': 'test@example.com',
        'hasPassword': false,
      };
      addTearDown(() => accountApi.user = null);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(false),
          home: const AccountScreen(changePassword: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Parolni tiklash'), findsOneWidget);
      expect(find.text('Kod yuborish'), findsOneWidget);
      expect(find.text('Joriy parol'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
