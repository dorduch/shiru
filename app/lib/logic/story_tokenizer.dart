/// One canonical tokenization of story body text, shared by the read-along
/// renderer, the highlight-index lookup, and the timing-derivation script
/// (`functions/dev/generate_starter_stories.mjs` uses the identical `\S+`
/// rule). Keeping a single definition guarantees the rendered word spans, the
/// timing array, and the index all refer to the same word list — so the gold
/// highlight can never drift off by a word at paragraph breaks.
library;

/// Half-open character range `[start, end)` of one word within the source text.
typedef WordRange = ({int start, int end});

final RegExp _word = RegExp(r'\S+');

/// Splits [text] into its whitespace-delimited words, each as a character
/// range. The ranges never cover the inter-word whitespace, so a renderer can
/// emit that whitespace (including `\n\n` paragraph breaks) verbatim.
List<WordRange> tokenizeStory(String text) {
  return [
    for (final m in _word.allMatches(text)) (start: m.start, end: m.end),
  ];
}

/// Index of the word being spoken at [positionSeconds], given per-word start
/// times (seconds, ascending, one per word). Returns the last word whose start
/// is `<= positionSeconds`, or null before the first word starts. Binary
/// search, so it is cheap to call every animation frame.
int? wordIndexForTime(List<double> wordStarts, double positionSeconds) {
  if (wordStarts.isEmpty || positionSeconds < wordStarts.first) return null;
  var lo = 0;
  var hi = wordStarts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (wordStarts[mid] <= positionSeconds) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}
