import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/illustrations.dart';
import 'package:lingoy/ui/design.dart';
import 'package:lingoy/screens/pictures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPictureCatalog);
  test('All 192 course words have photos; ambiguous aliases keep their selected meaning', () {
    expect(starterPictureWords.length, 192);
    expect(starterPictureWords.every((p) => p.asset.endsWith('.webp')), true);
    expect(pictureFor('aeroplane')!.asset, pictureFor('airplane')!.asset);
    expect(pictureFor('bike')!.asset, pictureFor('motorcycle')!.asset);
    expect(pictureFor('plane')!.asset, isNot(pictureFor('airplane')!.asset));
    expect(pictureFor('mouse')!.meaning, 'kompyuter sichqonchasi');
  });

  testWidgets('10000-entry gallery mounts only a viewport of image widgets', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(theme: appTheme(false), home: const PicturesScreen()),
    );
    await t.pump();
    expect(pictureWords.length, 10000);
    expect(find.byType(WordArt).evaluate().length, lessThan(32));
    await t.enterText(find.byType(TextField), 'acorn');
    await t.pump();
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == 'acorn'),
      findsOneWidget,
    );
    expect(find.byType(WordArt).evaluate().length, lessThan(8));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('Hidden pages release decoded illustration references', (
    t,
  ) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, active, child) =>
              TickerMode(enabled: active, child: child!),
          child: Center(
            child: WordArt(starterPictureWords.first, width: 80, height: 80),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump();
    expect(find.byType(AppIcon), findsNothing);
    enabled.value = false;
    await t.pump();
    expect(find.byType(AppIcon), findsOneWidget);
    enabled.value = true;
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await t.pump();
    expect(find.byType(AppIcon), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Light mode keeps feedback short; system reduced motion wins', (
    t,
  ) async {
    Duration? duration;
    Widget host(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MotionPolicy(
          light: true,
          child: Builder(
            builder: (c) {
              duration = motionDuration(c, 680);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await t.pumpWidget(host(false));
    expect(duration!.inMilliseconds, lessThanOrEqualTo(180));
    expect(duration!.inMilliseconds, greaterThan(0));
    await t.pumpWidget(host(true));
    expect(duration, Duration.zero);
  });

  test(
    'Picture word aliases have a selected meaning and a real bundled image',
    () async {
      final examples = ['aeroplane', 'cafe', 'peacock', 'screw', 'seahorse'];
      for (final word in examples) {
        final p = pictureFor(word)!;
        expect(p.senseId, isNotEmpty);
        expect(
          (await rootBundle.load(p.asset)).lengthInBytes,
          greaterThan(100),
        );
      }
      expect(pictureFor('screw')!.visualLabel, 'screw');
    },
  );
}
