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
