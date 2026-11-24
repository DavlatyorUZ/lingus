import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/ui/search_tools.dart';

void main() {
  testWidgets(
    'Online tools open and the compact language control preserves input',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final input = TextEditingController(text: 'apple');
      final reverse = ValueNotifier(false);
      addTearDown(input.dispose);
      addTearDown(reverse.dispose);
      var queries = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(true),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const ComingTools(),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<bool>(
                    valueListenable: reverse,
                    builder: (_, value, _) => SearchComposer(
                      controller: input,
                      reverse: value,
                      busy: false,
                      onSwap: () => reverse.value = !reverse.value,
                      onSearch: () => queries++,
                      onClear: input.clear,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tez kunda'), findsNothing);
      await t.tap(find.byKey(const ValueKey('search-language')));
      await t.pumpAndSettle();
      expect(reverse.value, true);
      expect(input.text, 'apple');
      await t.tap(find.byTooltip('Qidirish'));
      await t.pumpAndSettle();
      expect(queries, 1);
      await t.tap(find.byKey(const ValueKey('coming-tool-0')));
      await t.pumpAndSettle();
      expect(find.text('Matn tarjimasi'), findsWidgets);
      expect(find.text('Tarjima qilish'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
