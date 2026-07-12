import 'dart:convert';

import 'package:flutter/services.dart';

import '../logic/story_tokenizer.dart';
import 'starter_story_service.dart';

/// Loads per-word audio timings for curated stories from the bundled
/// `*.timing.json` assets named in the starter-story manifest. Generated and
/// uploaded cards have no manifest entry, so they get `null` and the player
/// falls back to a linear estimate.
class CuratedTimingService {
  CuratedTimingService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  // id -> timing asset path, loaded once from the manifest.
  Map<String, String>? _timingAssetById;
  // id -> manifest storyText, used to sanity-check a bundled timing file's
  // word count against the exact text it claims to describe.
  Map<String, String>? _storyTextById;
  // Per-card word-start cache (null = no timing for this card).
  final Map<String, List<double>?> _cache = {};

  /// Ascending per-word start times (seconds) for [cardId], or `null` when the
  /// card is not a curated story, has no bundled timing, or the bundled
  /// timing fails the sanity gate below.
  Future<List<double>?> wordStartsFor(String cardId) async {
    if (_cache.containsKey(cardId)) return _cache[cardId];

    final assets = await _loadManifestIndex();
    final asset = assets[cardId];
    if (asset == null) return _cache[cardId] = null;

    try {
      final json = jsonDecode(await _bundle.loadString(asset)) as Map;
      final words = (json['words'] as List)
          .map((w) => (w as Map)['start'] as num)
          .map((n) => n.toDouble())
          .toList(growable: false);

      if (!_isValidTiming(cardId, words)) {
        return _cache[cardId] = null;
      }

      return _cache[cardId] = words;
    } catch (_) {
      return _cache[cardId] = null;
    }
  }

  /// Runtime guard mirroring the backend `deriveWordStarts` sanity gate
  /// (`functions/src/timing.ts`): a bundled `.timing.json` is only trusted
  /// when it has exactly one finite, non-negative, non-decreasing start per
  /// `\S+` word of the manifest's `storyText` (tokenized the same way the
  /// read-along renderer tokenizes it, via `tokenizeStory`). A stale asset,
  /// a hand-edited story text, or a bad regeneration run would otherwise
  /// silently desync the highlight from the words on screen — falling back
  /// to the linear-estimate path is strictly better than a mismatched one.
  /// When the manifest has no `storyText` for this id (older manifest
  /// shape), the word-count check is skipped and only the numeric sanity
  /// checks apply.
  bool _isValidTiming(String cardId, List<double> words) {
    final storyText = _storyTextById?[cardId];
    if (storyText != null) {
      final expectedWordCount = tokenizeStory(storyText).length;
      if (words.length != expectedWordCount) return false;
    }
    for (var i = 0; i < words.length; i++) {
      final v = words[i];
      if (!v.isFinite || v < 0) return false;
      if (i > 0 && v < words[i - 1]) return false;
    }
    return true;
  }

  Future<Map<String, String>> _loadManifestIndex() async {
    final cached = _timingAssetById;
    if (cached != null) return cached;
    final manifest =
        jsonDecode(await _bundle.loadString(StarterStoryService.manifestAsset))
            as List<dynamic>;
    final index = <String, String>{};
    final storyTextIndex = <String, String>{};
    for (final item in manifest) {
      final map = item as Map;
      final id = map['id'] as String?;
      final timingAsset = map['timingAsset'] as String?;
      final storyText = map['storyText'] as String?;
      if (id != null && timingAsset != null) index[id] = timingAsset;
      if (id != null && storyText != null) storyTextIndex[id] = storyText;
    }
    _storyTextById = storyTextIndex;
    return _timingAssetById = index;
  }
}
