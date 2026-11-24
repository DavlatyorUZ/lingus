import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lingoy/core/illustrations.dart';
import 'package:lingoy/ui/design.dart';

void main() {
  testWidgets(
    'Refined starter illustrations render as a high-density contact sheet',
    (t) async {
      t.view.physicalSize = const Size(2160, 1760);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(loadPictureCatalog);
      await t.runAsync(() async {
        final loader = FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
        await loader.load();
      });
      const words = [
        'apple',
        'banana',
        'orange',
        'pear',
        'peach',
        'grape',
        'strawberry',
        'watermelon',
        'pineapple',
        'lemon',
        'cherry',
        'mango',
        'bread',
        'rice',
        'cheese',
        'egg',
        'milk',
        'water',
        'coffee',
        'tea',
        'house',
        'bed',
        'teacher',
        'listen',
      ];
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(false),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('art-sheet'),
              child: Container(
                color: const Color(0xFFFAF7F2),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lingoy 2.0 · 192 ta asosiy rasmdan namuna',
                      style: display(27),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: .94,
                        physics: const NeverScrollableScrollPhysics(),
                        children: words
                            .map(
                              (word) => Column(
                                children: [
                                  WordArt(
                                    pictureFor(word)!,
                                    width: 128,
                                    height: 128,
                                    radius: 18,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    word,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    pictureFor(word)!.meaning,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF74667C),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final b = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('art-sheet')),
        );
        final image = await b.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('test/goldens/art_studio.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}
