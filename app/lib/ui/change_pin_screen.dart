import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pin_provider.dart';

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
          setState(() {
            _step = _ChangePinStep.enterNew;
            _input = '';
          });
        } else {
          setState(() => _input = '');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wrong code')),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Codes don't match")),
          );
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
      data: (currentPin) => Scaffold(
        backgroundColor: const Color(0xFFF6F7F8),
        body: Row(
          children: [
            // Left side
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(4, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: index < _input.length
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFD1D5DB),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            // Right side — keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: _buildKeypad(currentPin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(String currentPin) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeyRow(['1', '2', '3'], currentPin),
        const SizedBox(height: 16),
        _buildKeyRow(['4', '5', '6'], currentPin),
        const SizedBox(height: 16),
        _buildKeyRow(['7', '8', '9'], currentPin),
        const SizedBox(height: 16),
        _buildKeyRow(['', '0', 'DEL'], currentPin),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys, String currentPin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        if (k.isEmpty) {
          return const SizedBox(width: 72, height: 72);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GestureDetector(
            onTap: () => _onKeyPress(k, currentPin),
            child: Container(
              width: 72,
              height: 72,
              decoration: k == 'DEL'
                  ? null
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
        );
      }).toList(),
    );
  }
}
