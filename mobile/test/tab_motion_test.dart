import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/ui/tab_motion.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;
  @override
  Widget build(BuildContext c) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('count=$count'),
  );
}

void main() {
  testWidgets('Each return replays movement without destroying tab state', (
    t,
  ) async {
    final active = ValueNotifier(true);
    addTearDown(active.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(false),
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, value, child) => TickerMode(
            enabled: value,
            child: TabMotion(active: value, child: child!),
          ),
          child: const Counter(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('count=0'));
    await t.pumpAndSettle();
    active.value = false;
    await t.pump();
    active.value = true;
    await t.pump();
    double x() => t
        .widget<Transform>(find.byKey(const ValueKey('tab-entry-transform')))
        .transform
        .storage[12];
    final start = x();
    expect(start, greaterThan(6));
    await t.pump(const Duration(milliseconds: 100));
    expect(x(), greaterThan(0));
    expect(x(), lessThan(start));
    expect(find.text('count=1'), findsOneWidget);
    await t.pumpAndSettle();
    expect(x(), 0);
  });
}
