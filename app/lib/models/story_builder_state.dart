enum StoryLength { short, medium }

enum TtsProvider { elevenlabs, cartesia }

enum StoryLanguage { english, spanish, hebrew }

enum StoryBuilderStep {
  heroSelection,
  themeSelection,
  languageSelection,
  providerSelection,
  voiceSelection,
  lengthSelection,
  generating,
  done,
  error,
}

const List<Map<String, String>> elevenLabsStockVoices = [
  {'id': 'EXAVITQu4vr4xnSDxMaL', 'name': 'Sarah', 'emoji': '👩'},
  {'id': '21m00Tcm4TlvDq8ikWAM', 'name': 'Rachel', 'emoji': '👩‍🦰'},
  {'id': 'ErXwobaYiN019PkySvjV', 'name': 'Antoni', 'emoji': '👨'},
  {'id': 'TxGEqnHWrfWFTfGW9XjX', 'name': 'Josh', 'emoji': '👨‍🦱'},
  {'id': 'onwK4e9ZLuTAKqWW03F9', 'name': 'Daniel', 'emoji': '👨'},
  {'id': 'XB0fDUnXU5powFXDhCwa', 'name': 'Charlotte', 'emoji': '👩‍🦳'},
];

const List<Map<String, String>> storyHeroes = [
  {'id': 'astronaut', 'label': 'Astronaut', 'emoji': '🧑‍🚀'},
  {'id': 'princess', 'label': 'Princess', 'emoji': '👸'},
  {'id': 'dragon', 'label': 'Dragon', 'emoji': '🐉'},
  {'id': 'robot', 'label': 'Robot', 'emoji': '🤖'},
  {'id': 'wizard', 'label': 'Wizard', 'emoji': '🧙'},
  {'id': 'cat', 'label': 'Cat', 'emoji': '🐱'},
  {'id': 'pirate', 'label': 'Pirate', 'emoji': '🏴‍☠️'},
  {'id': 'fairy', 'label': 'Fairy', 'emoji': '🧚'},
];

const List<Map<String, String>> storyThemes = [
  {'id': 'space', 'label': 'Space Adventure', 'emoji': '🚀'},
  {'id': 'underwater', 'label': 'Underwater', 'emoji': '🐠'},
  {'id': 'forest', 'label': 'Enchanted Forest', 'emoji': '🌳'},
  {'id': 'treasure', 'label': 'Treasure Hunt', 'emoji': '🗺️'},
  {'id': 'time_travel', 'label': 'Time Travel', 'emoji': '⏰'},
  {'id': 'candy_land', 'label': 'Candy Land', 'emoji': '🍭'},
];

const Map<String, String> heroColors = {
  'astronaut': '#E0E7FF',
  'princess': '#FCE7F3',
  'dragon': '#FEE2E2',
  'robot': '#E0F2FE',
  'wizard': '#EDE9FE',
  'cat': '#FEF9C3',
  'pirate': '#F1F5F9',
  'fairy': '#F0FDF4',
};

const List<Map<String, String>> storyLanguages = [
  {'id': 'english', 'label': 'English', 'emoji': '🇺🇸'},
  {'id': 'spanish', 'label': 'Spanish', 'emoji': '🇪🇸'},
  {'id': 'hebrew', 'label': 'Hebrew', 'emoji': '🇮🇱'},
];

extension StoryLanguageExt on StoryLanguage {
  String get cartesiaCode => switch (this) {
    StoryLanguage.english => 'en',
    StoryLanguage.spanish => 'es',
    StoryLanguage.hebrew => 'he',
  };

  String get displayName => switch (this) {
    StoryLanguage.english => 'English',
    StoryLanguage.spanish => 'Spanish',
    StoryLanguage.hebrew => 'Hebrew',
  };

  String get promptInstruction => switch (this) {
    StoryLanguage.english => 'Write in simple, clear English. Short sentences. Words a 4-year-old can understand.',
    StoryLanguage.spanish => 'Write in simple, clear Spanish. Short sentences. Words a 4-year-old can understand.',
    StoryLanguage.hebrew => 'Write in simple, clear Hebrew. Short sentences. Words a 4-year-old can understand.',
  };
}

class StoryBuilderState {
  static const _sentinel = Object();

  final StoryBuilderStep step;
  final String? selectedHero;
  final String? selectedTheme;
  final StoryLanguage? selectedLanguage;
  final TtsProvider? selectedProvider;
  final String? selectedVoiceId;
  final String? selectedSamplePath;
  final StoryLength? selectedLength;
  final String? generatedStoryText;
  final String? generatedAudioPath;
  final String? errorMessage;
  final double progress;

  const StoryBuilderState({
    this.step = StoryBuilderStep.heroSelection,
    this.selectedHero,
    this.selectedTheme,
    this.selectedLanguage,
    this.selectedProvider,
    this.selectedVoiceId,
    this.selectedSamplePath,
    this.selectedLength,
    this.generatedStoryText,
    this.generatedAudioPath,
    this.errorMessage,
    this.progress = 0.0,
  });

  StoryBuilderState copyWith({
    StoryBuilderStep? step,
    String? selectedHero,
    String? selectedTheme,
    StoryLanguage? selectedLanguage,
    TtsProvider? selectedProvider,
    Object? selectedVoiceId = _sentinel,
    Object? selectedSamplePath = _sentinel,
    StoryLength? selectedLength,
    String? generatedStoryText,
    String? generatedAudioPath,
    String? errorMessage,
    double? progress,
  }) {
    return StoryBuilderState(
      step: step ?? this.step,
      selectedHero: selectedHero ?? this.selectedHero,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      selectedVoiceId: selectedVoiceId == _sentinel
          ? this.selectedVoiceId
          : selectedVoiceId as String?,
      selectedSamplePath: selectedSamplePath == _sentinel
          ? this.selectedSamplePath
          : selectedSamplePath as String?,
      selectedLength: selectedLength ?? this.selectedLength,
      generatedStoryText: generatedStoryText ?? this.generatedStoryText,
      generatedAudioPath: generatedAudioPath ?? this.generatedAudioPath,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}
