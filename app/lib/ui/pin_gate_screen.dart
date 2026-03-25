import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class PinGateScreen extends ConsumerStatefulWidget {
  const PinGateScreen({Key? key}) : super(key: key);

  @override
  _PinGateScreenState createState() => _PinGateScreenState();
}

class _PinGateScreenState extends ConsumerState<PinGateScreen> {
  String _pin = '';
  final String _correctPin = '1234';

  void _onKeyPress(String key) {
    if (key == 'DEL') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else if (_pin.length < 4) {
      setState(() => _pin += key);
      if (_pin.length == 4) {
        if (_pin == _correctPin) {
          ref.read(parentAuthProvider.notifier).state = true;
          context.go('/parent');
        } else {
          setState(() => _pin = '');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('קוד PIN שגוי')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 32),
                    onPressed: () => context.pop(),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const Text('להורים בלבד! 🔒', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('הזינו קוד PIN בן 4 ספרות', style: TextStyle(fontSize: 20, color: Color(0xFF6B7280))),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: index < _pin.length ? const Color(0xFF1A1A1A) : const Color(0xFFD1D5DB),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              _buildKeypad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        const SizedBox(height: 24),
        _buildKeyRow(['4', '5', '6']),
        const SizedBox(height: 24),
        _buildKeyRow(['7', '8', '9']),
        const SizedBox(height: 24),
        _buildKeyRow(['', '0', 'DEL']),
      ]
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox(width: 100, height: 100);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: () => _onKeyPress(k),
            child: Container(
              width: 100, height: 100,
              decoration: k == 'DEL' ? null : const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))]
              ),
              alignment: Alignment.center,
              child: k == 'DEL' 
                 ? const Icon(Icons.backspace_rounded, size: 32, color: Color(0xFF9CA3AF))
                 : Text(k, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)))
            )
          )
        );
      }).toList()
    );
  }
}
