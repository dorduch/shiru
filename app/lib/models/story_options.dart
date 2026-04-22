enum StoryHero {
  knight,
  wizard,
  astronaut,
  pirate,
  fairy,
  dragon,
  robot,
  lion,
  bunny,
  superhero;

  String get displayName => switch (this) {
        StoryHero.knight => 'Knight / Princess',
        StoryHero.wizard => 'Wizard',
        StoryHero.astronaut => 'Astronaut',
        StoryHero.pirate => 'Pirate',
        StoryHero.fairy => 'Fairy',
        StoryHero.dragon => 'Dragon',
        StoryHero.robot => 'Robot',
        StoryHero.lion => 'Lion Cub',
        StoryHero.bunny => 'Bunny',
        StoryHero.superhero => 'Superhero',
      };

  String get emoji => switch (this) {
        StoryHero.knight => '🧝',
        StoryHero.wizard => '🧙',
        StoryHero.astronaut => '👨‍🚀',
        StoryHero.pirate => '🏴‍☠️',
        StoryHero.fairy => '🧚',
        StoryHero.dragon => '🐉',
        StoryHero.robot => '🤖',
        StoryHero.lion => '🦁',
        StoryHero.bunny => '🐰',
        StoryHero.superhero => '🦸',
      };

  String get promptName => switch (this) {
        StoryHero.knight => 'brave knight or princess',
        StoryHero.wizard => 'wise wizard',
        StoryHero.astronaut => 'adventurous astronaut',
        StoryHero.pirate => 'friendly pirate',
        StoryHero.fairy => 'magical fairy',
        StoryHero.dragon => 'friendly dragon',
        StoryHero.robot => 'curious robot',
        StoryHero.lion => 'brave lion cub',
        StoryHero.bunny => 'curious bunny',
        StoryHero.superhero => 'kind superhero',
      };
}

enum StoryTheme {
  adventure,
  bedtime,
  friendship,
  magic,
  space,
  ocean,
  forest,
  funny,
  birthday,
  kindness;

  String get displayName => switch (this) {
        StoryTheme.adventure => 'Adventure / Quest',
        StoryTheme.bedtime => 'Bedtime / Sleepy',
        StoryTheme.friendship => 'Friendship',
        StoryTheme.magic => 'Magic & Spells',
        StoryTheme.space => 'Space',
        StoryTheme.ocean => 'Ocean / Underwater',
        StoryTheme.forest => 'Enchanted Forest',
        StoryTheme.funny => 'Funny / Silly',
        StoryTheme.birthday => 'Birthday Surprise',
        StoryTheme.kindness => 'Kindness / Helping',
      };

  String get emoji => switch (this) {
        StoryTheme.adventure => '⚔️',
        StoryTheme.bedtime => '🌙',
        StoryTheme.friendship => '🤝',
        StoryTheme.magic => '✨',
        StoryTheme.space => '🚀',
        StoryTheme.ocean => '🌊',
        StoryTheme.forest => '🌲',
        StoryTheme.funny => '😂',
        StoryTheme.birthday => '🎂',
        StoryTheme.kindness => '💛',
      };

  String get promptName => switch (this) {
        StoryTheme.adventure => 'exciting adventure and quest',
        StoryTheme.bedtime => 'calm bedtime story with a peaceful, sleepy ending',
        StoryTheme.friendship => 'making a new friend and working together',
        StoryTheme.magic => 'magical world full of spells and enchantments',
        StoryTheme.space => 'space exploration with planets and stars',
        StoryTheme.ocean => 'underwater ocean adventure with sea creatures',
        StoryTheme.forest => 'enchanted forest with talking animals',
        StoryTheme.funny => 'funny and silly adventure full of laughs',
        StoryTheme.birthday => 'birthday party surprise and celebration',
        StoryTheme.kindness => 'act of kindness and helping others',
      };

  String get color => switch (this) {
        StoryTheme.adventure => '#7c2d12',
        StoryTheme.bedtime => '#1e1b4b',
        StoryTheme.friendship => '#831843',
        StoryTheme.magic => '#4a1d96',
        StoryTheme.space => '#0f172a',
        StoryTheme.ocean => '#0c4a6e',
        StoryTheme.forest => '#14532d',
        StoryTheme.funny => '#713f12',
        StoryTheme.birthday => '#9d174d',
        StoryTheme.kindness => '#854d0e',
      };
}

enum StoryLanguage {
  en,
  he,
  es;

  String get displayName => switch (this) {
        StoryLanguage.en => 'English',
        StoryLanguage.he => 'עברית',
        StoryLanguage.es => 'Español',
      };

  String get flag => switch (this) {
        StoryLanguage.en => '🇺🇸',
        StoryLanguage.he => '🇮🇱',
        StoryLanguage.es => '🇪🇸',
      };

  String get promptLabel => switch (this) {
        StoryLanguage.en => 'English',
        StoryLanguage.he => 'Hebrew',
        StoryLanguage.es => 'Spanish',
      };
}

enum StoryLength {
  short,
  long;

  String get displayName => switch (this) {
        StoryLength.short => 'Short',
        StoryLength.long => 'Long',
      };

  int get targetWordCount => switch (this) {
        StoryLength.short => 350,
        StoryLength.long => 800,
      };
}
