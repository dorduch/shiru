import 'storytime_models.dart';

/// Subtitle shown on a story tile/row for each origin.
String storyOriginSubtitle(StoryOrigin origin) {
  switch (origin) {
    case StoryOrigin.curated:
      return 'Ready-made';
    case StoryOrigin.uploaded:
      return 'Your audio';
    case StoryOrigin.generated:
      return 'Your story';
  }
}

/// Lower-case phrase used inside accessibility labels.
String storyOriginSemantics(StoryOrigin origin) {
  switch (origin) {
    case StoryOrigin.curated:
      return 'ready-made story';
    case StoryOrigin.uploaded:
      return 'your audio';
    case StoryOrigin.generated:
      return 'your story';
  }
}
