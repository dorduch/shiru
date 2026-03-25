enum StoryLength { short, medium }

enum StoryBuilderStep {
  heroSelection,
  themeSelection,
  lengthSelection,
  generating,
  done,
  error,
}

const List<Map<String, String>> storyHeroes = [
  {'id': 'astronaut', 'label': 'אסטרונאוט', 'emoji': '🧑‍🚀'},
  {'id': 'princess', 'label': 'נסיכה', 'emoji': '👸'},
  {'id': 'dragon', 'label': 'דרקון', 'emoji': '🐉'},
  {'id': 'robot', 'label': 'רובוט', 'emoji': '🤖'},
  {'id': 'wizard', 'label': 'קוסם', 'emoji': '🧙'},
  {'id': 'cat', 'label': 'חתול', 'emoji': '🐱'},
  {'id': 'pirate', 'label': 'פיראט', 'emoji': '🏴‍☠️'},
  {'id': 'fairy', 'label': 'פיה', 'emoji': '🧚'},
];

const List<Map<String, String>> storyThemes = [
  {'id': 'space', 'label': 'הרפתקה בחלל', 'emoji': '🚀'},
  {'id': 'underwater', 'label': 'מתחת למים', 'emoji': '🐠'},
  {'id': 'forest', 'label': 'יער קסום', 'emoji': '🌳'},
  {'id': 'treasure', 'label': 'ציד אוצרות', 'emoji': '🗺️'},
  {'id': 'time_travel', 'label': 'מסע בזמן', 'emoji': '⏰'},
  {'id': 'candy_land', 'label': 'ארץ הממתקים', 'emoji': '🍭'},
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

class StoryBuilderState {
  final StoryBuilderStep step;
  final String? selectedHero;
  final String? selectedTheme;
  final StoryLength? selectedLength;
  final String? generatedStoryText;
  final String? generatedAudioPath;
  final String? errorMessage;
  final double progress;

  const StoryBuilderState({
    this.step = StoryBuilderStep.heroSelection,
    this.selectedHero,
    this.selectedTheme,
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
      selectedLength: selectedLength ?? this.selectedLength,
      generatedStoryText: generatedStoryText ?? this.generatedStoryText,
      generatedAudioPath: generatedAudioPath ?? this.generatedAudioPath,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}
