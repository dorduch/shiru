import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/pin_provider.dart';
import '../services/analytics_service.dart';
import '../services/key_value_store.dart';
import '../theme/app_responsive.dart';
import '../theme/lantern_tokens.dart';
import '../theme/app_typography.dart';
import '../theme/app_shadows.dart';
import '../theme/app_radius.dart';
import 'widgets/lantern/lantern.dart';

const _kFailedAttemptsKey = 'pin_failed_attempts';
const _kLockUntilKey = 'pin_lock_until';

enum _PinFlowStep { enter, create, confirm }

class PinGateScreen extends ConsumerStatefulWidget {
  final String nextLocation;

  const PinGateScreen({super.key, required this.nextLocation});

  @override
  ConsumerState<PinGateScreen> createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  _PinFlowStep _step = _PinFlowStep.enter;
  String _input = '';
  String _newPin = '';
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  bool get _isLocked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);

  int get _secondsRemaining => _lockedUntil == null
      ? 0
      : _lockedUntil!.difference(DateTime.now()).inSeconds.clamp(0, 30);

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLockState() async {
    final store = ref.read(keyValueStoreProvider);
    final attemptsStr = await store.read(key: _kFailedAttemptsKey);
    final lockUntilStr = await store.read(key: _kLockUntilKey);
    if (attemptsStr == null && lockUntilStr == null) return;
    final attempts = int.tryParse(attemptsStr ?? '') ?? 0;
    final lockUntilMs = int.tryParse(lockUntilStr ?? '');
    final lockUntil = lockUntilMs != null && lockUntilMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lockUntilMs)
        : null;
    if (!mounted) return;
    setState(() {
      _failedAttempts = attempts;
      _lockedUntil = lockUntil;
    });
    if (_isLocked) _startLockTimer();
  }

  Future<void> _persistLockState() async {
    final store = ref.read(keyValueStoreProvider);
    await store.write(
      key: _kFailedAttemptsKey,
      value: _failedAttempts.toString(),
    );
    if (_lockedUntil != null) {
      await store.write(
        key: _kLockUntilKey,
        value: _lockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> _clearLockState() async {
    final store = ref.read(keyValueStoreProvider);
    await store.write(key: _kFailedAttemptsKey, value: '0');
    await store.write(key: _kLockUntilKey, value: '0');
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
      if (!_isLocked) {
        _lockTimer?.cancel();
      }
    });
  }

  void _syncStepWithSavedPin(String? savedPin) {
    if (savedPin == null && _step == _PinFlowStep.enter) {
      _step = _PinFlowStep.create;
    }
  }

  Future<void> _onKeyPress(String key, String? savedPin) async {
    if (_isLocked) {
      return;
    }

    HapticFeedback.lightImpact();

    if (key == 'DEL') {
      if (_input.isNotEmpty) {
        setState(() => _input = _input.substring(0, _input.length - 1));
      }
      return;
    }

    if (_input.length >= 4) {
      return;
    }

    setState(() => _input += key);

    if (_input.length == 4) {
      await _handleComplete(savedPin);
    }
  }

  Future<void> _handleComplete(String? savedPin) async {
    if (savedPin != null) {
      if (_input == savedPin) {
        _failedAttempts = 0;
        await _clearLockState();
        ref.read(parentAuthProvider.notifier).state = true;
        AnalyticsService.instance.logParentAreaEntered();
        if (mounted) {
          context.go(widget.nextLocation);
        }
        return;
      }

      _failedAttempts++;
      setState(() => _input = '');
      if (_failedAttempts >= 5) {
        setState(
          () => _lockedUntil = DateTime.now().add(const Duration(seconds: 30)),
        );
        await _persistLockState();
        _startLockTimer();
      } else {
        await _persistLockState();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
        }
      }
      return;
    }

    if (_step == _PinFlowStep.create) {
      setState(() {
        _newPin = _input;
        _input = '';
        _step = _PinFlowStep.confirm;
      });
      return;
    }

    if (_input == _newPin) {
      try {
        await ref.read(pinProvider.notifier).updatePin(_newPin);
        ref.read(parentAuthProvider.notifier).state = true;
        AnalyticsService.instance.logParentAreaEntered();
        if (mounted) {
          context.go(widget.nextLocation);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _input = '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t save your PIN. Please try again.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _input = '';
      _newPin = '';
      _step = _PinFlowStep.create;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PINs don't match")));
    }
  }

  String _title(String? savedPin) {
    if (savedPin != null) {
      return 'Parent PIN';
    }

    return _step == _PinFlowStep.confirm
        ? 'Confirm your PIN'
        : 'Create a parent PIN';
  }

  String _subtitle(String? savedPin) {
    if (savedPin != null) {
      return 'Enter the 4 digits for the grown-up area';
    }

    return _step == _PinFlowStep.confirm
        ? 'One more time, just to be sure.'
        : 'Choose 4 digits only the grown-ups in your home will know';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final pinAsync = ref.watch(pinProvider);
    final isPortrait = AppResponsive.isPortrait(context);
    final horizontalPadding = AppResponsive.basePadding(context);
    final verticalPadding = AppResponsive.spacing(context, 16);

    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(
          child: pinAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: tokens.lantern),
            ),
            error: (err, _) => Center(
              child: Text(
                'Something went wrong loading your PIN.',
                // hueCoral: the established Lantern destructive/error color
                // used for the same purpose elsewhere (AgeGateScreen,
                // storytime_screens.dart), swapped in for Material's
                // generic colorScheme.error for visual consistency with
                // the rest of the app — same judgment call as Batch 5's
                // AgeGateScreen.
                style: AppTypography.bodySmall.copyWith(
                  color: tokens.hueCoral,
                ),
              ),
            ),
            data: (savedPin) {
              _syncStepWithSavedPin(savedPin);

              final intro = _buildIntro(savedPin, context, tokens);
              final keypad = _buildKeypad(savedPin, context, tokens);

              if (isPortrait) {
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - (verticalPadding * 2),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(
                              AppResponsive.spacing(context, 24),
                            ),
                            decoration: BoxDecoration(
                              color: tokens.nightCard,
                              borderRadius: AppRadius.sheet,
                              boxShadow: AppShadows.elevated,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                intro,
                                SizedBox(
                                  height: AppResponsive.spacing(context, 24),
                                ),
                                Center(child: keypad),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: intro,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: keypad,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(
      String? savedPin, BuildContext context, LanternTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: AppResponsive.iconSize(context, 28),
            color: tokens.moonDim,
          ),
          onPressed: () => context.go('/'),
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          'GROWN-UPS ONLY',
          // moonDim, not a cream-specific accent: the old AppColors.eyebrow
          // burnt-terracotta was cream-specific — see spec §3. Same
          // resolution used in every prior batch (e.g. AgeGateScreen).
          style: AppTypography.eyebrow.copyWith(color: tokens.moonDim),
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          _title(savedPin),
          style: AppTypography.displayMedium.copyWith(color: tokens.moon),
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          _subtitle(savedPin),
          style: AppTypography.bodySmall.copyWith(color: tokens.moonDim),
        ),
      ],
    );
  }

  Widget _buildKeypad(
      String? savedPin, BuildContext context, LanternTokens tokens) {
    return LanternKeypad(
      enteredLength: _input.length,
      totalDigits: 4,
      locked: _isLocked,
      lockSecondsRemaining: _secondsRemaining,
      onKeyPress: (key) => _onKeyPress(key, savedPin),
    );
  }
}
