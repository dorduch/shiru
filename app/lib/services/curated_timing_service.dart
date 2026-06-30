import 'dart:convert';

import 'package:flutter/services.dart';

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
  // Per-card word-start cache (null = no timing for this card).
  final Map<String, List<double>?> _cache = {};

  /// Ascending per-word start times (seconds) for [cardId], or `null` when the
  /// card is not a curated story or has no bundled timing.
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
      return _cache[cardId] = words;
    } catch (_) {
      return _cache[cardId] = null;
    }
  }

  Future<Map<String, String>> _loadManifestIndex() async {
    final cached = _timingAssetById;
    if (cached != null) return cached;
    final manifest =
        jsonDecode(await _bundle.loadString(StarterStoryService.manifestAsset))
            as List<dynamic>;
    final index = <String, String>{};
    for (final item in manifest) {
      final map = item as Map;
      final id = map['id'] as String?;
      final timingAsset = map['timingAsset'] as String?;
      if (id != null && timingAsset != null) index[id] = timingAsset;
    }
    return _timingAssetById = index;
  }
}
