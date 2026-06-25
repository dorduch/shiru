import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../pixel_sprite.dart';
import '../../../models/sprites.dart';
import 'storytime.dart';

/// Developer gallery — instantiates every Storytime component in realistic
/// states, in BOTH day and bedtime surfaces.
///
/// Route: `/dev/gallery`
/// Or push manually:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const ComponentGalleryScreen()),
/// );
/// ```
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() =>
      _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  // Demo state
  int _wizardStep = 1;
  int _selectedChoice = 0;
  bool _toggle1 = true;
  bool _toggle2 = false;
  int _segSel = 1;
  int _toneChipSel = 0;
  bool _recording = false;
  bool _playerPlaying = false;
  double _playerProgress = 0.35;
  int _tab = 0;
  int _highlightedWord = 3;

  static const _storyText =
      'Once upon a time, in a forest full of glowing mushrooms, '
      'a tiny dragon named Pip discovered a hidden door.';

  @override
  Widget build(BuildContext context) {
    // Outer scaffold uses day theme (inherited from app).
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text('Component Gallery',
            style: AppTypography.headlineSmall.copyWith(color: AppColors.ink)),
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Day Surface ─────────────────────────────────────────────────
            _GallerySection(label: 'Buttons — Day Surface', children: [
              _Row(children: [
                StButton(
                  label: 'Create Story',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              _Row(children: [
                StButton(
                  label: 'Save',
                  variant: StButtonVariant.dark,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                StButton(
                  label: 'Cancel',
                  variant: StButtonVariant.ghost,
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              _Row(children: [
                StButton(
                  label: 'With Icon',
                  variant: StButtonVariant.soft,
                  leading: const Icon(Icons.add),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 8),
              StButton(
                label: 'Full Width Ember',
                fullWidth: true,
                onTap: () {},
              ),
            ]),

            _GallerySection(label: 'Text Fields', children: [
              StTextField(
                label: 'Your child\'s name',
                hint: 'e.g. Luna',
              ),
              const SizedBox(height: 12),
              const StField(
                label: 'Story title',
                placeholder: 'The Dragon and the Moon',
              ),
            ]),

            _GallerySection(label: 'Section Header', children: [
              StSectionHeader(
                eyebrow: 'Step 1 of 5',
                title: 'Choose a character',
                sub: 'Who will star in this story?',
              ),
              const SizedBox(height: 16),
              StSectionHeader(
                eyebrow: 'Settings',
                title: 'Content & Safety',
                centerAlign: true,
              ),
            ]),

            _GallerySection(label: 'Choice Cards', children: [
              Row(
                children: [
                  Expanded(
                    child: StChoiceCard(
                      name: 'Dragon',
                      selected: _selectedChoice == 0,
                      thumbnail: PixelSprite(
                        sprite: predefinedSprites['moon']!,
                        scale: 4.0,
                      ),
                      onTap: () => setState(() => _selectedChoice = 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StChoiceCard(
                      name: 'Rocket',
                      selected: _selectedChoice == 1,
                      thumbnail: PixelSprite(
                        sprite: predefinedSprites['rocket']!,
                        scale: 4.0,
                      ),
                      onTap: () => setState(() => _selectedChoice = 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StChoiceCard(
                      name: 'Puppy',
                      selected: _selectedChoice == 2,
                      thumbnail: PixelSprite(
                        sprite: predefinedSprites['dog']!,
                        scale: 4.0,
                      ),
                      onTap: () => setState(() => _selectedChoice = 2),
                    ),
                  ),
                ],
              ),
            ]),

            _GallerySection(label: 'Tiles', children: [
              Row(
                children: [
                  Expanded(
                    child: StTile(
                      label: 'Bedtime',
                      sublabel: '3 stories',
                      color: const Color(0xFFD4C5F9),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StTile(
                      label: 'Adventure',
                      sublabel: '5 stories',
                      color: const Color(0xFFFAD4A0),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StTile(
                label: 'Dragon Quest',
                sublabel: 'Fantasy · 2 min',
                color: const Color(0xFFC5E8D4),
                big: true,
                onTap: () {},
              ),
            ]),

            _GallerySection(label: 'List Rows', children: [
              StRow(
                title: 'Grandma Rose',
                subtitle: 'Family voice · Ready',
                avatarInitial: 'G',
                avatarColor: AppColors.ember,
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.ink3, size: 20),
                onTap: () {},
              ),
              const SizedBox(height: 8),
              StRow(
                title: 'Dad\'s Voice',
                subtitle: 'Family tier required',
                avatarInitial: 'D',
                avatarColor: AppColors.dusk,
                trailing: const StLockPill(),
              ),
              const SizedBox(height: 8),
              StRow(
                title: 'Wizard Wally',
                subtitle: 'Built-in narrator',
                avatarInitial: 'W',
                avatarColor: AppColors.night2,
                trailing: const StSoonTag(),
              ),
            ]),

            _GallerySection(label: 'Dots (Wizard Steps)', children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StDots(totalSteps: 5, activeStep: _wizardStep),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _wizardStep = (_wizardStep - 1).clamp(0, 4)),
                    child: const Text('Prev'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _wizardStep = (_wizardStep + 1).clamp(0, 4)),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ]),

            _GallerySection(label: 'Segment Control', children: [
              StSegment(
                options: const ['Off', 'On', 'Ask'],
                selectedIndex: _segSel,
                onChanged: (i) => setState(() => _segSel = i),
              ),
            ]),

            _GallerySection(label: 'Toggle', children: [
              Row(
                children: [
                  Text('Notifications',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.ink)),
                  const Spacer(),
                  StToggle(
                    value: _toggle1,
                    onChanged: (v) => setState(() => _toggle1 = v),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Night mode',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.ink)),
                  const Spacer(),
                  StToggle(
                    value: _toggle2,
                    onChanged: (v) => setState(() => _toggle2 = v),
                  ),
                ],
              ),
            ]),

            _GallerySection(label: 'Hint', children: [
              const StHint(
                text: 'Speak clearly and at a normal pace. We\'ll do the rest!',
              ),
              const SizedBox(height: 8),
              const StHint(
                icon: Icons.warning_amber_rounded,
                text: 'This voice will be used across all new stories.',
              ),
            ]),

            _GallerySection(label: 'Chips & Pills', children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const StChip(label: 'Fantasy'),
                  StChip(
                      label: 'Adventure',
                      color: AppColors.ember.withValues(alpha: 0.15)),
                  StToneChip(
                    label: 'Gentle',
                    selected: _toneChipSel == 0,
                    onTap: () => setState(() => _toneChipSel = 0),
                  ),
                  StToneChip(
                    label: 'Silly',
                    selected: _toneChipSel == 1,
                    onTap: () => setState(() => _toneChipSel = 1),
                  ),
                  StToneChip(
                    label: 'Spooky',
                    selected: _toneChipSel == 2,
                    onTap: () => setState(() => _toneChipSel = 2),
                  ),
                  const StLockPill(),
                  const StSoonTag(),
                ],
              ),
            ]),

            _GallerySection(label: 'Parent Gate (PIN)', children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: StParentGate(
                  onCompleted: (pin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PIN entered: $pin')),
                    );
                  },
                ),
              ),
            ]),

            _GallerySection(label: 'Tab Bar (Day)', children: [
              StTabBar(
                items: const [
                  StTabItem(icon: Icons.home_rounded, label: 'Home'),
                  StTabItem(icon: Icons.headphones_rounded, label: 'Listen'),
                  StTabItem(icon: Icons.person_rounded, label: 'Profile'),
                ],
                currentIndex: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ]),

            // ─── Dark / Bedtime Surface ───────────────────────────────────────
            _GallerySection(
              label: 'DARK / BEDTIME SURFACE',
              labelColor: AppColors.accent2,
              children: [
                // Wrap dark components in bedtime theme
                Theme(
                  data: StorytimeTheme.bedtime,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.night3, AppColors.night2, AppColors.night1],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Buttons on dark surface
                        _SubLabel(text: 'Buttons — dark surface'),
                        const SizedBox(height: 12),
                        StButton(
                          label: 'Create Story',
                          fullWidth: true,
                          onTap: () {},
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: StButton(
                                label: 'Cancel',
                                variant: StButtonVariant.line,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StButton(
                                label: 'Dark',
                                variant: StButtonVariant.dark,
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _SubLabel(text: 'Voice Capture'),
                        const SizedBox(height: 16),
                        // CaptureRing
                        Center(
                          child: StCaptureRing(
                            progress: 0.6,
                            status: 'Recording…',
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Prompt
                        const StPrompt(
                          promptText:
                              '"The stars were hiding behind a curtain of clouds."',
                        ),
                        const SizedBox(height: 24),
                        // Record button + wave
                        Center(
                          child: Column(
                            children: [
                              StRecordButton(
                                isRecording: _recording,
                                onTap: () =>
                                    setState(() => _recording = !_recording),
                              ),
                              const SizedBox(height: 16),
                              StVoiceWave(active: _recording),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Scene Player
                _SubLabel(text: 'Scene Player', labelColor: AppColors.ink),
                const SizedBox(height: 12),
                Theme(
                  data: StorytimeTheme.bedtime,
                  child: SizedBox(
                    height: 420,
                    child: StScenePlayer(
                      title: 'The Dragon and the Moon',
                      bodyText: _storyText,
                      isPlaying: _playerPlaying,
                      progress: _playerProgress,
                      highlightedWordIndex: _highlightedWord,
                      elapsed: '0:42',
                      total: '2:08',
                      artPanel: Container(
                        color: AppColors.night3,
                        child: Center(
                          child: PixelSprite(
                            sprite: predefinedSprites['moon']!,
                            scale: 8.0,
                          ),
                        ),
                      ),
                      onPlayPause: () =>
                          setState(() => _playerPlaying = !_playerPlaying),
                      onSeek: (v) => setState(() => _playerProgress = v),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // Word highlight controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() =>
                          _highlightedWord = (_highlightedWord - 1).clamp(
                              0,
                              _storyText.split(' ').length - 1)),
                      child: const Text('◀ Word'),
                    ),
                    TextButton(
                      onPressed: () => setState(() =>
                          _highlightedWord = (_highlightedWord + 1).clamp(
                              0,
                              _storyText.split(' ').length - 1)),
                      child: const Text('Word ▶'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Gallery helpers ──────────────────────────────────────────────────────────

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.label,
    required this.children,
    this.labelColor,
  });

  final String label;
  final List<Widget> children;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.eyebrow.copyWith(
              color: labelColor ?? AppColors.accent2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel({required this.text, this.labelColor});
  final String text;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelLarge.copyWith(
        color: labelColor ?? AppColors.cream.withValues(alpha: 0.5),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
