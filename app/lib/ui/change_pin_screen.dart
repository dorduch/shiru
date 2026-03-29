import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pin_provider.dart';
import '../theme/app_responsive.dart';

enum _ChangePinStep { enterCurrent, enterNew, confirmNew }

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({Key? key}) : super(key: key);

  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
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
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
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
        return 'Enter current code';
      case _ChangePinStep.enterNew:
        return 'Enter new code';
      case _ChangePinStep.confirmNew:
        return 'Confirm new code';
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

  void _onKeyPress(String key, String currentPin) {
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
      _handleComplete(currentPin);
    }
  }

  void _handleComplete(String currentPin) {
    switch (_step) {
      case _ChangePinStep.enterCurrent:
        if (_input == currentPin) {
          _failedAttempts = 0;
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
            _startLockTimer();
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Wrong code')));
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
          ref.read(pinProvider.notifier).updatePin(_newPin);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code changed successfully')),
          );
          context.pop();
        } else {
          setState(() {
            _step = _ChangePinStep.enterNew;
            _input = '';
            _newPin = '';
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Codes don't match")));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinAsync = ref.watch(pinProvider);

    return pinAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => const Scaffold(
        backgroundColor: Color(0xFFF6F7F8),
        body: Center(
          child: Text(
            'Error loading PIN code',
            style: TextStyle(fontSize: 20, color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
      data: (currentPin) {
        if (currentPin == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7F8),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Set up a parent PIN first.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
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
          body: Row(
            children: [
              // Left side
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                          onPressed: () => context.pop(),
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _title,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stepSubtitle,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: List.generate(4, (index) {
                          final filled = index < _input.length;
                          return Semantics(
                            label:
                                'PIN digit ${index + 1} of 4, ${filled ? "entered" : "empty"}',
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              width: 20,
                              height: 20,
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
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: _buildKeypad(currentPin, context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypad(String currentPin, BuildContext context) {
    final keySize = AppResponsive.isTablet(context)
        ? 80.0
        : (MediaQuery.of(context).size.width < 600 ? 64.0 : 72.0);
    if (_isLocked) {
      return SizedBox(
        width: 280,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text(
              'Too many attempts.\nTry again in ${_secondsRemaining}s.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
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
        const SizedBox(height: 16),
        _buildKeyRow(['4', '5', '6'], currentPin, keySize),
        const SizedBox(height: 16),
        _buildKeyRow(['7', '8', '9'], currentPin, keySize),
        const SizedBox(height: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    ? const Icon(
                        Icons.backspace_rounded,
                        size: 28,
                        color: Color(0xFF9CA3AF),
                      )
                    : Text(
                        k,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
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
