import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/theme/lantern_tokens.dart';
import 'package:shiru/ui/widgets/storytime/st_scene_player.dart';

Future<void> _pump(WidgetTester tester, {required int? highlightedWordIndex}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: StorytimeTheme.bedtime,
      home: Scaffold(
        body: StScenePlayer(
          title: 'A Story',
          bodyText: 'Once upon a time a dragon flew',
          isPlaying: false,
          progress: 0.2,
          highlightedWordIndex: highlightedWordIndex,
        ),
      ),
    ),
  );
}

void main() {
  const tokens = LanternTokens.night();

  // Finds the RichText built by _HighlightText specifically — several other
  // widgets (Icon, Text) also render via RichText internally, so scope the
  // search to the one whose flattened plain text matches the story body.
  RichText findBodyRichText(WidgetTester tester) {
    final matches = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((w) => (w.text as TextSpan).toPlainText() ==
            'Once upon a time a dragon flew');
    expect(matches, hasLength(1));
    return matches.single;
  }

  testWidgets('highlights the word at highlightedWordIndex in the lantern accent color',
      (tester) async {
    await _pump(tester, highlightedWordIndex: 3);

    final root = findBodyRichText(tester).text as TextSpan;
    final spans = root.children!.cast<TextSpan>();

    // "Once upon a time a dragon flew" — word index 3 is "time".
    final highlighted =
        spans.where((s) => s.text == 'time').map((s) => s.style).toList();
    expect(highlighted, hasLength(1));
    expect(highlighted.single!.color, tokens.lantern);

    // Every other word-bearing span stays the dimmed base color, not lantern.
    final others = spans.where((s) => s.text != 'time' && s.text!.trim().isNotEmpty);
    for (final span in others) {
      expect(span.style!.color, isNot(tokens.lantern));
    }
  });

  testWidgets('renders plain, unsplit text with no highlight when highlightedWordIndex is null',
      (tester) async {
    await _pump(tester, highlightedWordIndex: null);

    // With no highlight, _HighlightText returns a plain Text (single string
    // span, no per-word children) rather than a multi-span RichText.
    final bodyRichTexts = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((w) => (w.text as TextSpan).toPlainText() ==
            'Once upon a time a dragon flew');
    for (final rt in bodyRichTexts) {
      expect((rt.text as TextSpan).children, isNull);
    }
    expect(find.text('Once upon a time a dragon flew'), findsOneWidget);
  });
}
