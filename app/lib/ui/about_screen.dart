import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'widgets/welcome_dialog.dart';

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
                    _WelcomeNoteRow(),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'Why Shiru exists',
                      body:
                          'Shiru exists to keep kids close to familiar voices without turning listening time into a content feed. It is for the small rituals that matter: a parent\'s goodnight message, a grandparent\'s story, a favorite song from home, or a voice note a child wants to hear again tomorrow.',
                    ),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'A real family flow',
                      body:
                          'A parent can record grandma reading a bedtime story, add cover art, and have it ready on the kid screen in a minute. Recording and importing audio should feel quick, so saving something meaningful takes a moment instead of turning into a whole project.',
                    ),
                    SizedBox(height: 16),
                    _AboutSection(
                      title: 'Built for family hands',
                      body:
                          'Parents stay in control of what gets added, while kids get a calm player with big artwork and simple playback. The whole product is meant to feel small on purpose: easy to manage, easy to understand, and easy to come back to.',
                    ),
                    SizedBox(height: 16),
                    _AboutPrivacy(),
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

class _AboutPrivacy extends StatelessWidget {
  const _AboutPrivacy();

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
            'Private by default',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Shiru keeps the experience intentionally small and local. The basics are simple:',
            style: AppTypography.bodySmall.copyWith(
              height: 1.65,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const _PrivacyPoint(
            title: 'Stored on device',
            body: 'Your family audio library stays on this device.',
          ),
          const SizedBox(height: 12),
          const _PrivacyPoint(
            title: 'No account required',
            body: 'You can set up and use Shiru without signing in.',
          ),
          const SizedBox(height: 12),
          const _PrivacyPoint(
            title: 'Audio never uploaded',
            body: 'Recordings and imported files are not sent to our servers.',
          ),
          const SizedBox(height: 12),
          const _PrivacyPoint(
            title: 'Anonymous analytics only',
            body: 'We only collect broad usage signals to improve the app.',
          ),
        ],
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacyPoint({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.bodySmall.copyWith(
                height: 1.65,
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '$title. ',
                  style: AppTypography.bodySmall.copyWith(
                    height: 1.65,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '…';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Version $version',
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(color: AppColors.textHint),
          ),
        );
      },
    );
  }
}

class _WelcomeNoteRow extends StatelessWidget {
  const _WelcomeNoteRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => showWelcomeDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome note',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Re-read the note from the maker.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
