import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../logic/age_gate_logic.dart';
import '../providers/adult_gate_provider.dart';
import '../theme/app_responsive.dart';
import '../theme/app_typography.dart';
import '../theme/app_shadows.dart';
import '../theme/app_radius.dart';
import '../theme/lantern_tokens.dart';
import 'widgets/lantern/lantern.dart';

class AgeGateScreen extends ConsumerStatefulWidget {
  final String nextLocation;

  const AgeGateScreen({super.key, required this.nextLocation});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  static const int _maxFailedAttempts = 3;
  static const int _cooldownSeconds = 60;

  DateTime? _selectedBirthDate;
  String? _errorMessage;
  bool _isSubmitting = false;

  int _failedAttempts = 0;
  DateTime? _cooldownEndsAt;
  Timer? _cooldownTimer;

  int get _cooldownSecondsLeft {
    if (_cooldownEndsAt == null) return 0;
    final remaining = _cooldownEndsAt!.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _isInCooldown => _cooldownSecondsLeft > 0;

  void _startCooldown() {
    _cooldownEndsAt = DateTime.now().add(
      const Duration(seconds: _cooldownSeconds),
    );
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _cooldownTimer?.cancel();
        return;
      }
      setState(() {});
      if (_cooldownSecondsLeft <= 0) {
        _cooldownTimer?.cancel();
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    if (_isInCooldown) return;
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? initialDate,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Your birthday',
    );

    if (!mounted || pickedDate == null) return;

    setState(() {
      _selectedBirthDate = pickedDate;
      _errorMessage = null;
    });
  }

  Future<void> _continue() async {
    if (_isInCooldown) return;

    final validationError = validateAdultBirthDate(
      _selectedBirthDate,
      DateTime.now(),
    );
    if (validationError != null) {
      _failedAttempts += 1;
      if (_failedAttempts >= _maxFailedAttempts) {
        _startCooldown();
        setState(() {
          _errorMessage =
              'Too many attempts. Please wait $_cooldownSeconds seconds.';
        });
      } else {
        setState(() => _errorMessage = validationError);
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(adultAgeVerifiedProvider.notifier).markVerified();
      if (!mounted) return;

      context.go(
        Uri(
          path: '/pin',
          queryParameters: {'next': widget.nextLocation},
        ).toString(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Could not save this step. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final selectedBirthDate = _selectedBirthDate;
    final inCooldown = _isInCooldown;
    final secondsLeft = _cooldownSecondsLeft;
    final basePadding = AppResponsive.basePadding(context);

    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.all(basePadding),
                  child: Container(
                    padding: EdgeInsets.all(AppResponsive.spacing(context, 28)),
                    decoration: BoxDecoration(
                      color: tokens.nightCard,
                      borderRadius: AppRadius.sheet,
                      boxShadow: AppShadows.elevated,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              size: AppResponsive.iconSize(context, 28),
                              color: tokens.moonDim,
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : () => context.go('/'),
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacing(context, 4)),
                        Text(
                          'GROWN-UPS ONLY',
                          // moonDim, not a cream-specific accent: `lantern`
                          // fails contrast for body/label text on `nightDeep`
                          // per the Composer's own rule, and the old
                          // AppColors.eyebrow burnt-terracotta was
                          // cream-specific — see spec §3.
                          style: AppTypography.eyebrow.copyWith(
                            color: tokens.moonDim,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacing(context, 8)),
                        Text(
                          'Grown-ups only for this part',
                          style: AppTypography.displayMedium.copyWith(
                            color: tokens.moon,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacing(context, 12)),
                        Text(
                          'This is where you set things up for your child. A quick birthday check keeps it for grown-ups only.',
                          style: AppTypography.bodySmall.copyWith(
                            color: tokens.moonDim,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: AppResponsive.spacing(context, 24)),
                        GestureDetector(
                          onTap: inCooldown ? null : _pickBirthDate,
                          child: Opacity(
                            opacity: inCooldown ? 0.4 : 1.0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppResponsive.spacing(context, 18),
                                vertical: AppResponsive.spacing(context, 20),
                              ),
                              decoration: BoxDecoration(
                                // nightDeep, not nightCard: this row is a
                                // recessed input well nested inside the
                                // nightCard card, matching the original's
                                // relationship (cream row-fill = cream
                                // Scaffold ground, both distinct from the
                                // paper card) — the well shows the ground
                                // color through the elevated card.
                                color: tokens.nightDeep,
                                borderRadius: AppRadius.medium,
                                border: Border.all(color: tokens.hush),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    color: tokens.moonDim,
                                  ),
                                  SizedBox(
                                    width: AppResponsive.spacing(context, 12),
                                  ),
                                  Expanded(
                                    child: Text(
                                      selectedBirthDate == null
                                          ? 'Choose birth date'
                                          : DateFormat.yMMMMd().format(
                                              selectedBirthDate,
                                            ),
                                      style: AppTypography.titleMedium.copyWith(
                                        color: selectedBirthDate == null
                                            ? tokens.moonFaint
                                            : tokens.moon,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: AppResponsive.iconSize(context, 18),
                                    color: tokens.moonFaint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (inCooldown) ...[
                          SizedBox(height: AppResponsive.spacing(context, 16)),
                          Text(
                            'Too many attempts. Try again in $secondsLeft second${secondsLeft == 1 ? '' : 's'}.',
                            style: AppTypography.labelLarge.copyWith(
                              // hueCoral: the established Lantern
                              // destructive/error color used for the same
                              // purpose elsewhere (storytime_screens.dart,
                              // family_voices_screens.dart), swapped in for
                              // Material's generic colorScheme.error for
                              // visual consistency with the rest of the app.
                              color: tokens.hueCoral,
                            ),
                          ),
                        ] else if (_errorMessage != null) ...[
                          SizedBox(height: AppResponsive.spacing(context, 16)),
                          Text(
                            _errorMessage!,
                            style: AppTypography.labelLarge.copyWith(
                              color: tokens.hueCoral,
                            ),
                          ),
                        ],
                        SizedBox(height: AppResponsive.spacing(context, 24)),
                        if (_isSubmitting)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: tokens.ctaGradient,
                              borderRadius: AppRadius.large,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  // On-accent color, matching GlowButton's own
                                  // convention for content on `ctaGradient`
                                  // (see glow_button.dart: label/leading icon
                                  // both use `tokens.nightDeep`).
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    tokens.nightDeep,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          GlowButton(
                            label: 'Continue',
                            onTap: inCooldown ? null : _continue,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
