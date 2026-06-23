import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/ui/parent_edit_screen.dart';

void main() {
  testWidgets('new card form adapts without overflow', (tester) async {
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
        const ProviderScope(child: MaterialApp(home: ParentEditScreen())),
      );
      await tester.pump();

      expect(find.text('New card'), findsWidgets);
      expect(find.text('Card preview'), findsOneWidget);
      expect(find.text('Change artwork'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
    }
  });
}
