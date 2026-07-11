import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

enum _ChangePinStep { enterCurrent, enterNew, confirmNew }

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _ChangePinStep _step = _ChangePinStep.enterCurrent;
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
      if (mounted) setState(() {});
      if (!_isLocked) _lockTimer?.cancel();
    });
  }

  String get _title {
    switch (_step) {
      case _ChangePinStep.enterCurrent:
        return 'Enter current PIN';
      case _ChangePinStep.enterNew:
        return 'Enter new PIN';
      case _ChangePinStep.confirmNew:
        return 'Confirm new PIN';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case _ChangePinStep.enterCurrent:
        return 'Step 1 of 3';
      case _ChangePinStep.enterNew:
        return 'Step 2 of 3';
      case _ChangePinStep.confirmNew:
        return 'Step 3 of 3';
    }
  }

  Future<void> _onKeyPress(String key, String currentPin) async {
    if (_isLocked) return;
    HapticFeedback.lightImpact();
    if (key == 'DEL') {
      if (_input.isNotEmpty) {
        setState(() => _input = _input.substring(0, _input.length - 1));
      }
      return;
    }

    if (_input.length >= 4) return;

    setState(() => _input += key);

    if (_input.length == 4) {
      await _handleComplete(currentPin);
    }
  }

  Future<void> _handleComplete(String currentPin) async {
    switch (_step) {
      case _ChangePinStep.enterCurrent:
        if (_input == currentPin) {
          _failedAttempts = 0;
          await _clearLockState();
          setState(() {
            _step = _ChangePinStep.enterNew;
            _input = '';
          });
        } else {
          _failedAttempts++;
          setState(() => _input = '');
          if (_failedAttempts >= 5) {
            setState(
              () => _lockedUntil = DateTime.now().add(
                const Duration(seconds: 30),
              ),
            );
            await _persistLockState();
            _startLockTimer();
          } else {
            await _persistLockState();
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Wrong PIN')));
          }
        }
        break;

      case _ChangePinStep.enterNew:
        setState(() {
          _newPin = _input;
          _step = _ChangePinStep.confirmNew;
          _input = '';
        });
        break;

      case _ChangePinStep.confirmNew:
        if (_input == _newPin) {
          try {
            await ref.read(pinProvider.notifier).updatePin(_newPin);
            AnalyticsService.instance.logPinChanged();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN changed successfully')),
            );
            context.pop();
          } catch (_) {
            if (!mounted) return;
            setState(() => _input = '');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Couldn\'t update your PIN. Please try again.'),
              ),
            );
          }
        } else {
          setState(() {
            _step = _ChangePinStep.enterNew;
            _input = '';
            _newPin = '';
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("PINs don't match")));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final pinAsync = ref.watch(pinProvider);
    final isPortrait = AppResponsive.isPortrait(context);
    final horizontalPadding = AppResponsive.basePadding(context);
    final verticalPadding = AppResponsive.spacing(context, 16);

    return pinAsync.when(
      loading: () => _groundScaffold(
        tokens,
        body: Center(
          child: CircularProgressIndicator(color: tokens.lantern),
        ),
      ),
      error: (err, _) => _groundScaffold(
        tokens,
        body: Center(
          child: Text(
            'Something went wrong loading your PIN.',
            style: AppTypography.bodySmall.copyWith(color: tokens.moon),
          ),
        ),
      ),
      data: (currentPin) {
        if (currentPin == null) {
          return _groundScaffold(
            tokens,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(AppResponsive.basePadding(context)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Set up a parent PIN first.',
                      style: AppTypography.headlineMedium.copyWith(
                        color: tokens.moon,
                      ),
                    ),
                    SizedBox(height: AppResponsive.spacing(context, 16)),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _groundScaffold(
          tokens,
          body: isPortrait
              ? LayoutBuilder(
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
                                _buildStepIntro(context, tokens),
                                SizedBox(
                                  height: AppResponsive.spacing(context, 24),
                                ),
                                Center(
                                  child: _buildKeypad(
                                      currentPin, context, tokens),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: _buildStepIntro(context, tokens),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      child: _buildKeypad(currentPin, context, tokens),
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// Shared Lantern-night ground (`nightMid → nightDeep` gradient) for this
  /// screen's four top-level Scaffolds (loading/error/no-pin-yet/data) —
  /// same recipe as `ParentAccessScreen`/`StoryComposerScreen` since this
  /// screen has no AppBar.
  Widget _groundScaffold(LanternTokens tokens, {required Widget body}) {
    return Scaffold(
      backgroundColor: tokens.nightDeep,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: tokens.nightGradient),
        child: SafeArea(child: body),
      ),
    );
  }

  Widget _buildStepIntro(BuildContext context, LanternTokens tokens) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: AppResponsive.iconSize(context, 28),
              color: tokens.moonDim,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        SizedBox(height: AppResponsive.spacing(context, 12)),
        Text(
          'CHANGE PIN',
          // moonDim, not a cream-specific accent: the old AppColors.eyebrow
          // burnt-terracotta was cream-specific — see spec §3. Same
          // resolution used in every prior batch (e.g. AgeGateScreen).
          style: AppTypography.eyebrow.copyWith(color: tokens.moonDim),
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          _title,
          textAlign: TextAlign.left,
          style: AppTypography.displayMedium.copyWith(color: tokens.moon),
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          _stepSubtitle,
          textAlign: TextAlign.left,
          style: AppTypography.bodySmall.copyWith(color: tokens.moonDim),
        ),
      ],
    );
  }

  Widget _buildKeypad(
      String currentPin, BuildContext context, LanternTokens tokens) {
    return LanternKeypad(
      enteredLength: _input.length,
      totalDigits: 4,
      locked: _isLocked,
      lockSecondsRemaining: _secondsRemaining,
      onKeyPress: (key) => _onKeyPress(key, currentPin),
    );
  }
}
