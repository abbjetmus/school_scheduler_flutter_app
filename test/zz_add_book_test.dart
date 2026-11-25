// TILLFÄLLIGT: skärmdumpar mot lokal PB. Tas bort efter körning.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:school_scheduler_flutter_app/core/pocketbase/pocketbase_client.dart';
import 'package:school_scheduler_flutter_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const scratch = String.fromEnvironment('SCRATCH');

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global = null;
    await loadFont('Figtree', [for (final w in [400, 500, 600, 700, 800]) '$scratch/fonts/Figtree-$w.ttf']);
    await loadFont('MaterialIcons', [const String.fromEnvironment('ICONS')]);
    SharedPreferences.setMockInitialValues({
      'pb_auth': File('$scratch/pb040/demo-auth.json').readAsStringSync(),
      'reader.sounds': false,
      'reader.keyboard': true,
    });
    await initializeDateFormatting('sv');
    await PocketBaseClient.initialize();
  });

  testWidgets('lägg till bok', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;

    Future<void> settle([int ms = 1500]) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> shot(String name) async {
      await expectLater(find.byType(AppRoot), matchesGoldenFile('$scratch/screens/$name.png'));
    }

    Future<void> blip(String code) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      void key(PhysicalKeyboardKey p, LogicalKeyboardKey l, String? ch) {
        HardwareKeyboard.instance.handleKeyEvent(
            KeyDownEvent(physicalKey: p, logicalKey: l, character: ch, timeStamp: Duration.zero));
        HardwareKeyboard.instance
            .handleKeyEvent(KeyUpEvent(physicalKey: p, logicalKey: l, timeStamp: Duration.zero));
      }
      for (final ch in code.split('')) {
        key(PhysicalKeyboardKey.keyA, LogicalKeyboardKey.keyA, ch);
      }
      key(PhysicalKeyboardKey.enter, LogicalKeyboardKey.enter, null);
      for (var i = 0; i < 4; i++) {
        await settle(1500);
      }
    }

    await tester.runAsync(() async {
      await tester.pumpWidget(const AppRoot(fontFamily: 'Figtree'));
    });
    await settle(2000);
    await tester.tap(find.text('Böcker').first);
    for (var i = 0; i < 4; i++) {
      await settle(2000);
    }
    await shot('add-0-bocker');

    // Streckkodsläsaren "skriver" ISBN när inget fält har fokus.
    await blip('9789127144941');
    for (var i = 0; i < 20 && find.text('Lejonburen: roman').evaluate().isEmpty; i++) {
      await settle(1000);
    }
    await shot('add-1-dialog');

    await tester.enterText(find.widgetWithText(TextField, 'Placering på hyllan'), 'Hylla B1');
    await tester.tap(find.byTooltip('Fler'));
    await tester.pump();
    await tester.tap(find.text('Spara i biblioteket'));
    for (var i = 0; i < 20 && find.text('Lägg till bok').evaluate().length > 1; i++) {
      await settle(1000);
    }
    await settle(2000);
    await settle(2000);
    await shot('add-2-vantar-etikett');

    await blip('E0040100AA000001');
    await shot('add-3-nasta');
    await blip('E0040100AA000002');
    await shot('add-4-klar');

    // Samma ISBN igen: boken finns, visas direkt.
    await blip('9789127144941');
    await shot('add-5-finns');
  });
}
