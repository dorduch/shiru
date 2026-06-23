import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/services/library_import_service.dart';
import 'package:shiru/ui/bulk_import_screen.dart';

void main() {
  testWidgets('empty state stays polished across phone and tablet layouts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BulkImportScreen())),
      );
      await tester.pump();

      expect(find.text('Import media'), findsOneWidget);
      expect(find.text('Add several cards at once'), findsOneWidget);
      expect(find.text('Choose files'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
    }
  });

  testWidgets('keeps valid audio and video drafts in a mixed bulk selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: BulkImportScreen(
            pickFiles: () async => FilePickerResult([
              PlatformFile(
                name: 'Bedtime Story.mp3',
                size: 1024,
                path: '/tmp/Bedtime Story.mp3',
              ),
              PlatformFile(
                name: 'Family Movie.mov',
                size: 2048,
                path: '/tmp/Family Movie.mov',
              ),
            ]),
            importMedia: (path, mediaType, duration) async => MediaSelection(
              path: path,
              mediaType: mediaType,
              duration: duration,
            ),
          ),
        ),
      ),
    );

    final chooseButton = find.text('Choose files');
    await tester.ensureVisible(chooseButton);
    await tester.tap(chooseButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Bedtime Story.mp3'), findsOneWidget);
    expect(find.text('Family Movie.mov'), findsOneWidget);
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.video_file_outlined), findsOneWidget);
    expect(find.text('Invalid'), findsNothing);
  });
}
