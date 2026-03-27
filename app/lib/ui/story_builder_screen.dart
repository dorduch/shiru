import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/story_builder_state.dart';
import '../providers/story_builder_provider.dart';
import '../providers/voice_profiles_provider.dart';
import 'widgets/story_option_card.dart';

class StoryBuilderScreen extends ConsumerStatefulWidget {
  const StoryBuilderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StoryBuilderScreen> createState() => _StoryBuilderScreenState();
}

class _StoryBuilderScreenState extends ConsumerState<StoryBuilderScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyBuilderProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: SafeArea(
        child: switch (state.step) {
          StoryBuilderStep.heroSelection => _buildHeroSelection(state),
          StoryBuilderStep.themeSelection => _buildThemeSelection(state),
          StoryBuilderStep.providerSelection => _buildProviderSelection(state),
          StoryBuilderStep.voiceSelection => _buildVoiceSelection(state),
          StoryBuilderStep.lengthSelection => _buildLengthSelection(state),
          StoryBuilderStep.generating => _buildGenerating(state),
          StoryBuilderStep.done => _buildDone(),
          StoryBuilderStep.error => _buildError(state),
        },
      ),
    );
  }

  // ─── Step indicators ──────────────────────────────────────────────────────

  Widget _buildStepDots(int activeIndex) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF8B5CF6) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ─── Back button ─────────────────────────────────────────────────────────

  Widget _buildBackButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  // ─── Shared header ────────────────────────────────────────────────────────

  Widget _buildHeader({
    required String title,
    required int dotIndex,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildBackButton(onTap: onBack),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          _buildStepDots(dotIndex),
        ],
      ),
    );
  }

  // ─── Screen 1: Hero selection ─────────────────────────────────────────────

  Widget _buildHeroSelection(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          title: '✨ Choose Hero',
          dotIndex: 0,
          onBack: () {
            HapticFeedback.mediumImpact();
            context.pop();
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              itemCount: storyHeroes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final hero = storyHeroes[index];
                return StoryOptionCard(
                  emoji: hero['emoji']!,
                  label: hero['label']!,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    notifier.selectHero(hero['id']!);
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Screen 2: Theme selection ────────────────────────────────────────────

  Widget _buildThemeSelection(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          title: '🎭 Choose Theme',
          dotIndex: 1,
          onBack: () {
            HapticFeedback.mediumImpact();
            notifier.goBack();
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              itemCount: storyThemes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final theme = storyThemes[index];
                return StoryOptionCard(
                  emoji: theme['emoji']!,
                  label: theme['label']!,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    notifier.selectTheme(theme['id']!);
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Screen 3: Provider selection ────────────────────────────────────────

  Widget _buildProviderSelection(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          title: '🔧 Choose Voice Engine',
          dotIndex: 2,
          onBack: () {
            HapticFeedback.mediumImpact();
            notifier.goBack();
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: StoryOptionCard(
                    emoji: '🔊',
                    label: 'ElevenLabs',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      notifier.selectProvider(TtsProvider.elevenlabs);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StoryOptionCard(
                    emoji: '🎵',
                    label: 'Cartesia',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      notifier.selectProvider(TtsProvider.cartesia);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Screen 4: Voice selection ────────────────────────────────────────────

  Widget _buildVoiceSelection(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);
    final profilesAsync = ref.watch(voiceProfilesProvider);
    final providerKey = state.selectedProvider == TtsProvider.elevenlabs ? 'elevenlabs' : 'cartesia';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          title: '🎤 Choose Voice',
          dotIndex: 3,
          onBack: () {
            HapticFeedback.mediumImpact();
            notifier.goBack();
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                profilesAsync.when(
                  data: (profiles) {
                    final filtered = profiles.where((p) => p.provider == providerKey).toList();
                    if (filtered.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Family Voices',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final profile = filtered[index];
                              return SizedBox(
                                width: 100,
                                child: StoryOptionCard(
                                  emoji: '🎤',
                                  label: profile.name,
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    notifier.selectVoice(profile.voiceId);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const Text(
                  'Stock Voices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 12),
                ref.watch(stockVoicesProvider(state.selectedProvider!)).when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (voices) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: voices.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final voice = voices[index];
                      return StoryOptionCard(
                        emoji: voice['emoji']!,
                        label: voice['name']!,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          notifier.selectVoice(voice['id']!);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Screen 5: Length selection ───────────────────────────────────────────

  Widget _buildLengthSelection(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          title: '📖 Choose Length',
          dotIndex: 4,
          onBack: () {
            HapticFeedback.mediumImpact();
            notifier.goBack();
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: StoryOptionCard(
                    emoji: '⚡',
                    label: 'Short',
                    subtitle: '~1 min',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      notifier.selectLength(StoryLength.short);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StoryOptionCard(
                    emoji: '📚',
                    label: 'Medium',
                    subtitle: '~3 min',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      notifier.selectLength(StoryLength.medium);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Screen 4: Generating ─────────────────────────────────────────────────

  Widget _buildGenerating(StoryBuilderState state) {
    final heroLabel = state.selectedHero != null
        ? storyHeroes
            .firstWhere(
              (h) => h['id'] == state.selectedHero,
              orElse: () => {'label': ''},
            )['label']!
        : '';
    final themeLabel = state.selectedTheme != null
        ? storyThemes
            .firstWhere(
              (t) => t['id'] == state.selectedTheme,
              orElse: () => {'label': ''},
            )['label']!
        : '';

    final isRecording = state.progress > 0.5;
    final title = isRecording ? 'Recording the story...' : 'Writing the story...';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '✨📖✨',
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (heroLabel.isNotEmpty && themeLabel.isNotEmpty)
              Text(
                '$heroLabel · $themeLabel',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            // Progress bar
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          color: const Color(0xFFE5E7EB),
                        ),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          widthFactor: state.progress.clamp(0.0, 1.0),
                          child: Container(
                            height: 12,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(state.progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8B5CF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Screen 5: Done ───────────────────────────────────────────────────────

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 48),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Story Ready!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'The story has been saved to your library',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.go('/');
              },
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4022C55E),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Back Home',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Screen 6: Error ──────────────────────────────────────────────────────

  Widget _buildError(StoryBuilderState state) {
    final notifier = ref.read(storyBuilderProvider.notifier);
    final errorText =
        state.errorMessage ?? 'An error occurred. Please try again.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '😢',
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorText,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Purple "Try again" button
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                notifier.reset();
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x408B5CF6),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // White outlined "Back" button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
