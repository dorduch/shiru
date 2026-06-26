import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../logic/age_gate_logic.dart';
import '../providers/adult_gate_provider.dart';
import '../theme/app_responsive.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/app_shadows.dart';
import '../theme/app_radius.dart';
import 'widgets/storytime/storytime.dart';

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
    final tokens = Theme.of(context).extension<StorytimeTokens>()!;
    final selectedBirthDate = _selectedBirthDate;
    final inCooldown = _isInCooldown;
    final secondsLeft = _cooldownSecondsLeft;
    final basePadding = AppResponsive.basePadding(context);

    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.all(basePadding),
                child: Container(
                  padding: EdgeInsets.all(AppResponsive.spacing(context, 28)),
                  decoration: BoxDecoration(
                    color: tokens.paper,
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
                            color: tokens.ink2,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => context.go('/'),
                        ),
                      ),
                      SizedBox(height: AppResponsive.spacing(context, 4)),
                      Text(
                        'GROWN-UPS ONLY',
                        style: tokens.eyebrow.copyWith(color: tokens.accent2),
                      ),
                      SizedBox(height: AppResponsive.spacing(context, 8)),
                      Text(
                        'Grown-ups only for this part',
                        style: AppTypography.displayMedium.copyWith(
                          color: tokens.ink,
                        ),
                      ),
                      SizedBox(height: AppResponsive.spacing(context, 12)),
                      Text(
                        'This is where you set things up for your child. A quick birthday check keeps it for grown-ups only.',
                        style: AppTypography.bodySmall.copyWith(
                          color: tokens.ink2,
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
                              color: tokens.cream,
                              borderRadius: AppRadius.medium,
                              border: Border.all(color: tokens.line),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  color: tokens.ink2,
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
                                          ? tokens.ink3
                                          : tokens.ink,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: AppResponsive.iconSize(context, 18),
                                  color: tokens.ink3,
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
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        SizedBox(height: AppResponsive.spacing(context, 16)),
                        Text(
                          _errorMessage!,
                          style: AppTypography.labelLarge.copyWith(
                            color: Theme.of(context).colorScheme.error,
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
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        StButton(
                          label: 'Continue',
                          variant: StButtonVariant.ember,
                          fullWidth: true,
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
    );
  }
}
