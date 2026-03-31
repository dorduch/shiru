import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundParent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'About Shiru',
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    _AboutHero(),
                    SizedBox(height: 20),
                    _AboutSection(
                      title: 'Made for familiar voices',
                      body:
                          'Shiru is built for the small moments that stay with kids: a bedtime recording from a parent, a favorite song from home, a story from a grandparent, or a message saved in someone\'s real voice. The goal is not endless content. The goal is a little collection that feels familiar, safe, and easy to come back to.',
                    ),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'Built for family hands',
                      body:
                          'Parents stay in control of what is added, while kids get a clean player with big artwork and simple playback. Recording and importing audio should feel quick, so adding something meaningful takes a moment instead of turning into a whole project.',
                    ),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'Private by default',
                      body:
                          'Shiru keeps the experience intentionally small. No account is required, and your audio library stays on the device. It is a personal collection for your family, not a feed, not a store, and not a place where a child can wander into the wrong thing.',
                    ),
                    SizedBox(height: 16),
                    _AboutHighlights(),
                    SizedBox(height: 20),
                    _AboutFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shiru',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'A gentle audio player for kids, with a parent space for stories, songs, and voice notes from home.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final String body;

  const _AboutSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: AppTypography.bodySmall.copyWith(
              height: 1.65,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHighlights extends StatelessWidget {
  const _AboutHighlights();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _HighlightChip(
          icon: Icons.mic_rounded,
          label: 'Record messages in the app',
        ),
        _HighlightChip(
          icon: Icons.library_music_rounded,
          label: 'Import your own audio files',
        ),
        _HighlightChip(
          icon: Icons.lock_outline_rounded,
          label: 'Protected parent area',
        ),
        _HighlightChip(
          icon: Icons.offline_bolt_rounded,
          label: 'No account or cloud required',
        ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HighlightChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Version 1.0.0',
        textAlign: TextAlign.center,
        style: AppTypography.labelLarge.copyWith(color: AppColors.textHint),
      ),
    );
  }
}
