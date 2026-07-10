enum AgeBand {
  early,
  middle,
  older;

  String get label => switch (this) {
    AgeBand.early => '3–5',
    AgeBand.middle => '6–7',
    AgeBand.older => '8–10',
  };

  int get targetWordCount => switch (this) {
    AgeBand.early => 350,
    AgeBand.middle => 550,
    AgeBand.older => 800,
  };
}

class ChildProfile {
  const ChildProfile({
    required this.name,
    required this.ageBand,
    required this.avatarSpriteKey,
  });

  final String name;
  final AgeBand ageBand;
  final String avatarSpriteKey;

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    name: json['name'] as String,
    ageBand: AgeBand.values.byName(json['ageBand'] as String),
    avatarSpriteKey: json['avatarSpriteKey'] as String,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'ageBand': ageBand.name,
    'avatarSpriteKey': avatarSpriteKey,
  };
}

enum StoryCharacter {
  prince,
  princess,
  doctor,
  builder,
  firefighter,
  animalFriend;

  String get label => switch (this) {
    StoryCharacter.prince => 'Prince',
    StoryCharacter.princess => 'Princess',
    StoryCharacter.doctor => 'Doctor',
    StoryCharacter.builder => 'Builder',
    StoryCharacter.firefighter => 'Firefighter',
    StoryCharacter.animalFriend => 'Animal friend',
  };

  String get emoji => switch (this) {
    StoryCharacter.prince => '🤴',
    StoryCharacter.princess => '👸',
    StoryCharacter.doctor => '🧑‍⚕️',
    StoryCharacter.builder => '👷',
    StoryCharacter.firefighter => '🧑‍🚒',
    StoryCharacter.animalFriend => '🦊',
  };
}

enum StoryScene {
  castle,
  space,
  underTheSea,
  forest,
  city,
  farm;

  String get label => switch (this) {
    StoryScene.castle => 'Castle',
    StoryScene.space => 'Space',
    StoryScene.underTheSea => 'Under the sea',
    StoryScene.forest => 'Forest',
    StoryScene.city => 'City',
    StoryScene.farm => 'Farm',
  };

  String get emoji => switch (this) {
    StoryScene.castle => '🏰',
    StoryScene.space => '🚀',
    StoryScene.underTheSea => '🌊',
    StoryScene.forest => '🌳',
    StoryScene.city => '🏙️',
    StoryScene.farm => '🚜',
  };
}

enum StoryTheme {
  friendship,
  bravery,
  bedtime,
  adventure,
  mystery,
  kindness;

  String get label => switch (this) {
    StoryTheme.friendship => 'Friendship',
    StoryTheme.bravery => 'Being brave',
    StoryTheme.bedtime => 'Bedtime calm',
    StoryTheme.adventure => 'Adventure',
    StoryTheme.mystery => 'Mystery',
    StoryTheme.kindness => 'Kindness',
  };

  String get emoji => switch (this) {
    StoryTheme.friendship => '🤝',
    StoryTheme.bravery => '🦁',
    StoryTheme.bedtime => '🌙',
    StoryTheme.adventure => '🗺️',
    StoryTheme.mystery => '🔍',
    StoryTheme.kindness => '💛',
  };

  String get color => switch (this) {
    StoryTheme.friendship => '#7FD1C4',
    StoryTheme.bravery => '#FFD66B',
    StoryTheme.bedtime => '#B59BFF',
    StoryTheme.adventure => '#FF9B8A',
    StoryTheme.mystery => '#83B8FF',
    StoryTheme.kindness => '#F6A6C1',
  };
}

enum StoryPlot {
  somethingGoesWrong,
  surpriseFriend,
  treasureHunt,
  problemToSolve,
  bigWin,
  magicMoment;

  String get label => switch (this) {
    StoryPlot.somethingGoesWrong => 'Something goes wrong',
    StoryPlot.surpriseFriend => 'A surprise friend',
    StoryPlot.treasureHunt => 'Treasure hunt',
    StoryPlot.problemToSolve => 'A problem to solve',
    StoryPlot.bigWin => 'A big win',
    StoryPlot.magicMoment => 'A magic moment',
  };

  String get emoji => switch (this) {
    StoryPlot.somethingGoesWrong => '⚡',
    StoryPlot.surpriseFriend => '🎁',
    StoryPlot.treasureHunt => '💎',
    StoryPlot.problemToSolve => '🧩',
    StoryPlot.bigWin => '🏆',
    StoryPlot.magicMoment => '🌈',
  };
}

/// Identifies which of the four story-concept slots on [StoryDraft] a
/// shuffle or slot-sheet interaction targets. Never includes the narrator —
/// narrator selection has its own vocabulary ([NarratorKey] / family voice).
enum SlotKind { character, scene, theme, plot }

enum NarratorKey {
  wizardWally,
  fairyFern,
  roboRay;

  String get label => switch (this) {
    NarratorKey.wizardWally => 'Wizard Wally',
    NarratorKey.fairyFern => 'Fairy Fern',
    NarratorKey.roboRay => 'Robo Ray',
  };

  String get description => switch (this) {
    NarratorKey.wizardWally => 'Warm and playful',
    NarratorKey.fairyFern => 'Gentle and soft',
    NarratorKey.roboRay => 'Fun and silly',
  };

  String get emoji => switch (this) {
    NarratorKey.wizardWally => '🧙',
    NarratorKey.fairyFern => '🧚',
    NarratorKey.roboRay => '🤖',
  };
}

enum StoryOrigin { curated, generated, uploaded }

enum StoryJobStatus { queued, writing, checking, narrating, ready, failed }

class StoryDraft {
  const StoryDraft({
    this.character,
    this.scene,
    this.theme,
    this.plot,
    this.narrator,
    this.familyVoiceId,
  });

  final StoryCharacter? character;
  final StoryScene? scene;
  final StoryTheme? theme;
  final StoryPlot? plot;
  final NarratorKey? narrator;

  /// When set, the narrator is a family voice rather than a built-in
  /// [NarratorKey]. The request will send `narratorKey = "family:<id>"`.
  final String? familyVoiceId;

  bool get isComplete =>
      character != null &&
      scene != null &&
      theme != null &&
      plot != null &&
      (narrator != null || familyVoiceId != null);

  /// Copy with new values. Pass [clearFamilyVoiceId] = true to unset
  /// [familyVoiceId] (e.g. when switching back to a built-in narrator).
  StoryDraft copyWith({
    StoryCharacter? character,
    StoryScene? scene,
    StoryTheme? theme,
    StoryPlot? plot,
    NarratorKey? narrator,
    String? familyVoiceId,
    bool clearFamilyVoiceId = false,
    bool clearNarrator = false,
  }) => StoryDraft(
    character: character ?? this.character,
    scene: scene ?? this.scene,
    theme: theme ?? this.theme,
    plot: plot ?? this.plot,
    narrator: clearNarrator ? null : (narrator ?? this.narrator),
    familyVoiceId: clearFamilyVoiceId
        ? null
        : (familyVoiceId ?? this.familyVoiceId),
  );

  /// The serialized narrator key sent to the backend.
  String get resolvedNarratorKey {
    if (familyVoiceId != null) return 'family:$familyVoiceId';
    return narrator!.name;
  }

  Map<String, String> toRequestJson() {
    if (!isComplete) throw StateError('Story draft is incomplete');
    return {
      'character': character!.name,
      'scene': scene!.name,
      'theme': theme!.name,
      'plot': plot!.name,
      'narratorKey': resolvedNarratorKey,
    };
  }
}
