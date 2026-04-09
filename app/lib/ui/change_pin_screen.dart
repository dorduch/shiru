import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pin_provider.dart';
import '../services/analytics_service.dart';
import '../services/key_value_store.dart';
import '../theme/app_responsive.dart';

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
    final pinAsync = ref.watch(pinProvider);
    final isPortrait = AppResponsive.isPortrait(context);
    final horizontalPadding = AppResponsive.basePadding(context);
    final verticalPadding = AppResponsive.spacing(context, 16);

    return pinAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(
          child: Text(
            'Something went wrong loading your PIN.',
            style: TextStyle(
              fontSize: AppResponsive.fontSize(context, 20),
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
      data: (currentPin) {
        if (currentPin == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7F8),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(AppResponsive.basePadding(context)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Set up a parent PIN first.',
                      style: TextStyle(
                        fontSize: AppResponsive.fontSize(context, 24),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
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

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F8),
          body: SafeArea(
            child: isPortrait
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x120F172A),
                                    blurRadius: 24,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildStepIntro(context),
                                  SizedBox(
                                    height: AppResponsive.spacing(context, 24),
                                  ),
                                  Center(
                                    child: _buildKeypad(currentPin, context),
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
                          child: _buildStepIntro(context),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: _buildKeypad(currentPin, context),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStepIntro(BuildContext context) {
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
            ),
            onPressed: () => context.pop(),
            color: const Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: AppResponsive.spacing(context, 24)),
        Text(
          _title,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: AppResponsive.fontSize(context, 28),
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: AppResponsive.spacing(context, 8)),
        Text(
          _stepSubtitle,
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: AppResponsive.fontSize(context, 18),
            color: const Color(0xFF6B7280),
          ),
        ),
        SizedBox(height: AppResponsive.spacing(context, 32)),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(4, (index) {
            final filled = index < _input.length;
            return Semantics(
              label:
                  'PIN digit ${index + 1} of 4, ${filled ? "entered" : "empty"}',
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: AppResponsive.spacing(context, 10),
                ),
                width: AppResponsive.spacing(context, 20),
                height: AppResponsive.spacing(context, 20),
                decoration: BoxDecoration(
                  color: filled
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFD1D5DB),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildKeypad(String currentPin, BuildContext context) {
    final keySize = AppResponsive.isPortrait(context)
        ? AppResponsive.buttonSize(context) + AppResponsive.spacing(context, 16)
        : AppResponsive.buttonSize(context);
    final keypadWidth = (keySize * 3) + AppResponsive.spacing(context, 60);
    if (_isLocked) {
      return SizedBox(
        width: keypadWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_clock,
              size: AppResponsive.iconSize(context, 48),
              color: const Color(0xFF9CA3AF),
            ),
            SizedBox(height: AppResponsive.spacing(context, 16)),
            Text(
              'Too many attempts.\nTry again in ${_secondsRemaining}s.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppResponsive.fontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeyRow(['1', '2', '3'], currentPin, keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(['4', '5', '6'], currentPin, keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(['7', '8', '9'], currentPin, keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(['', '0', 'DEL'], currentPin, keySize),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, String currentPin, double keySize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        if (k.isEmpty) {
          return SizedBox(width: keySize, height: keySize);
        }
        return Semantics(
          label: k == 'DEL' ? 'Delete' : k,
          button: true,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.spacing(context, 10),
            ),
            child: GestureDetector(
              onTap: () => _onKeyPress(k, currentPin),
              child: Container(
                width: keySize,
                height: keySize,
                decoration: k == 'DEL'
                    ? const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      )
                    : const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                alignment: Alignment.center,
                child: k == 'DEL'
                    ? Icon(
                        Icons.backspace_rounded,
                        size: AppResponsive.iconSize(context, 28),
                        color: const Color(0xFF9CA3AF),
                      )
                    : Text(
                        k,
                        style: TextStyle(
                          fontSize: AppResponsive.fontSize(context, 28),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
