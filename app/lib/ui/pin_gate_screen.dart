import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/pin_provider.dart';
import '../theme/app_responsive.dart';

class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({Key? key}) : super(key: key);

  @override
  _PinGateScreenState createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  String _pin = '';
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  bool get _isLocked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
  int get _secondsRemaining => _lockedUntil == null ? 0 : _lockedUntil!.difference(DateTime.now()).inSeconds.clamp(0, 30);

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

  void _onKeyPress(String key, String correctPin) {
    if (_isLocked) return;
    HapticFeedback.lightImpact();
    if (key == 'DEL') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else if (_pin.length < 4) {
      setState(() => _pin += key);
      if (_pin.length == 4) {
        if (_pin == correctPin) {
          _failedAttempts = 0;
          ref.read(parentAuthProvider.notifier).state = true;
          context.go('/parent');
        } else {
          _failedAttempts++;
          setState(() => _pin = '');
          if (_failedAttempts >= 5) {
            setState(() => _lockedUntil = DateTime.now().add(const Duration(seconds: 30)));
            _startLockTimer();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wrong PIN')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinAsync = ref.watch(pinProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Row(
        children: [
          // Left side: back button, title, subtitle, dot indicators
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 28),
                    onPressed: () => context.pop(),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Parents Only! 🔒',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter 4-digit PIN',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(4, (index) {
                      final filled = index < _pin.length;
                      return Semantics(
                        label: 'PIN digit ${index + 1} of 4, ${filled ? "entered" : "empty"}',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
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
          // Right side: keypad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: pinAsync.when(
              loading: () => const SizedBox(
                width: 280,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => const SizedBox(
                width: 280,
                child: Center(
                  child: Text(
                    'Error loading PIN',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ),
              data: (correctPin) => _buildKeypad(correctPin, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(String correctPin, BuildContext context) {
    final keySize = AppResponsive.isTablet(context) ? 80.0 : (MediaQuery.of(context).size.width < 600 ? 64.0 : 72.0);
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeyRow(['1', '2', '3'], correctPin, keySize),
        const SizedBox(height: 14),
        _buildKeyRow(['4', '5', '6'], correctPin, keySize),
        const SizedBox(height: 14),
        _buildKeyRow(['7', '8', '9'], correctPin, keySize),
        const SizedBox(height: 14),
        _buildKeyRow(['', '0', 'DEL'], correctPin, keySize),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, String correctPin, double keySize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        if (k.isEmpty) return SizedBox(width: keySize, height: keySize);
        return Semantics(
          label: k == 'DEL' ? 'Delete' : k,
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => _onKeyPress(k, correctPin),
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
