import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/story_options.dart';
import '../providers/cards_provider.dart';
import '../services/analytics_service.dart';
import '../services/story_service.dart';

class ParentGenerateStoryScreen extends ConsumerStatefulWidget {
  const ParentGenerateStoryScreen({super.key});

  @override
  ConsumerState<ParentGenerateStoryScreen> createState() =>
      _ParentGenerateStoryScreenState();
}

class _ParentGenerateStoryScreenState
    extends ConsumerState<ParentGenerateStoryScreen> {
  int _step = 0;
  StoryHero? _hero;
  StoryTheme? _theme;
  StoryLanguage _language = StoryLanguage.en;
  StoryLength _length = StoryLength.short;
  String? _error;
  String _status = 'Writing story…';

  Future<void> _generate() async {
    setState(() {
      _step = 3;
      _error = null;
      _status = 'Writing story…';
    });

    try {
      final cards = ref.read(cardsProvider).value ?? [];
      final card = await StoryService().generate(
        hero: _hero!,
        theme: _theme!,
        language: _language,
        length: _length,
        cardPosition: cards.length,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      await ref.read(cardsProvider.notifier).addCard(card);
      AnalyticsService.instance.logCardCreated(method: 'ai_story');
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = 2;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step != 3,
      child: Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F8),
        elevation: 0,
        leading: _step == 3
            ? const SizedBox.shrink()
            : _step > 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => setState(() {
                      _step -= 1;
                      _error = null;
                    }),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => context.pop(),
                  ),
        title: Text(
          _stepTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _HeroStep(
                  selected: _hero,
                  onSelect: (h) => setState(() {
                    _hero = h;
                    _step = 1;
                  }),
                ),
              1 => _ThemeStep(
                  selected: _theme,
                  onSelect: (t) => setState(() {
                    _theme = t;
                    _step = 2;
                  }),
                ),
              2 => _OptionsStep(
                  language: _language,
                  length: _length,
                  error: _error,
                  onLanguageChanged: (l) => setState(() => _language = l),
                  onLengthChanged: (l) => setState(() => _length = l),
                  onGenerate: _generate,
                  hero: _hero!,
                  theme: _theme!,
                ),
              _ => _LoadingStep(status: _status),
            },
          ),
        ),
      ),
      ),
    );
  }

  String get _stepTitle => switch (_step) {
        0 => 'Pick a hero',
        1 => 'Pick a theme',
        2 => 'Language & length',
        _ => 'Creating your story…',
      };
}

// ─── Step 1: Hero ────────────────────────────────────────────────────────────

class _HeroStep extends StatelessWidget {
  final StoryHero? selected;
  final ValueChanged<StoryHero> onSelect;

  const _HeroStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _PickGrid<StoryHero>(
      items: StoryHero.values,
      selected: selected,
      emoji: (h) => h.emoji,
      label: (h) => h.displayName,
      onSelect: onSelect,
    );
  }
}

// ─── Step 2: Theme ───────────────────────────────────────────────────────────

class _ThemeStep extends StatelessWidget {
  final StoryTheme? selected;
  final ValueChanged<StoryTheme> onSelect;

  const _ThemeStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _PickGrid<StoryTheme>(
      items: StoryTheme.values,
      selected: selected,
      emoji: (t) => t.emoji,
      label: (t) => t.displayName,
      onSelect: onSelect,
    );
  }
}

// ─── Step 3: Options + Generate ──────────────────────────────────────────────

class _OptionsStep extends StatelessWidget {
  final StoryHero hero;
  final StoryTheme theme;
  final StoryLanguage language;
  final StoryLength length;
  final String? error;
  final ValueChanged<StoryLanguage> onLanguageChanged;
  final ValueChanged<StoryLength> onLengthChanged;
  final VoidCallback onGenerate;

  const _OptionsStep({
    required this.hero,
    required this.theme,
    required this.language,
    required this.length,
    required this.error,
    required this.onLanguageChanged,
    required this.onLengthChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Text(hero.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Text(theme.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${hero.displayName} · ${theme.displayName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Language
          const Text(
            'Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: StoryLanguage.values.map((lang) {
              final isSelected = lang == language;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onLanguageChanged(lang),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF111827)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${lang.flag} ${lang.displayName}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Length
          const Text(
            'Length',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: StoryLength.values.map((len) {
              final isSelected = len == length;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onLengthChanged(len),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF111827)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      len.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ],

          const Spacer(),

          // Generate button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onGenerate,
              child: const Text(
                '✨  Generate Story',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _LoadingStep extends StatelessWidget {
  final String status;
  const _LoadingStep({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: Color(0xFF111827),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            status,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generic pick grid ───────────────────────────────────────────────────────

class _PickGrid<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) emoji;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  const _PickGrid({
    required this.items,
    required this.selected,
    required this.emoji,
    required this.label,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = item == selected;
          return GestureDetector(
            onTap: () => onSelect(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF111827)
                      : const Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji(item), style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(
                    label(item),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
