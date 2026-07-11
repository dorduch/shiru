import 'package:flutter/material.dart';

import '../../../theme/app_responsive.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/lantern_tokens.dart';

/// Shared PIN-entry keypad — the Lantern equivalent of the bespoke
/// digit-grid/dot-indicator/lockout-overlay trio duplicated (with a few
/// drifted literals) across `PinGateScreen` and `ChangePinScreen`.
///
/// Extracted per the Batch 6 dedup verdict: only this chrome — the digit
/// grid (1-9, blank, 0, DEL), the 4-dot input indicator, and the
/// locked-out overlay (icon + countdown text) — was a true near-duplicate.
/// Each screen's own step semantics, success navigation, and lockout
/// `Timer`/persistence stay in the screen; this widget is intentionally
/// "dumb" — it renders whatever [enteredLength]/[totalDigits]/[locked]/
/// [lockSecondsRemaining] say and reports taps via [onKeyPress], nothing
/// more.
///
/// Canonical values below were unified from the two screens' drifted
/// copies, defaulting to `PinGateScreen`'s literals (it has real test
/// coverage — `pin_gate_screen_test.dart` — to validate the visual result
/// against; `ChangePinScreen` had none):
/// - keypad width spacing: `48` (not `ChangePinScreen`'s `60`)
/// - per-key horizontal padding: `8` (not `10`)
/// - DEL key fill: same `tokens.nightCard` as digit keys, unconditionally
///   (not `ChangePinScreen`'s conditional cream/paper split)
/// - DEL icon color: `tokens.moon` (not `ChangePinScreen`'s dimmer ink2)
/// - spacing between the dot row and the grid/lockout below it: `24` (not
///   `ChangePinScreen`'s `32`)
///
/// **Critical for `find.text(digit)` test compatibility**: key-caps render
/// as literal `Text('0')`...`Text('9')` / `Text('DEL')` — do not swap these
/// for icons or any other label scheme.
class LanternKeypad extends StatelessWidget {
  const LanternKeypad({
    super.key,
    required this.enteredLength,
    required this.totalDigits,
    required this.onKeyPress,
    this.locked = false,
    this.lockSecondsRemaining,
  });

  /// How many digits have been entered so far — drives the dot indicator.
  final int enteredLength;

  /// Total digits expected (4, for a PIN) — drives the dot indicator.
  final int totalDigits;

  /// Called with `'0'`-`'9'` or `'DEL'` on every key tap. Not called while
  /// [locked].
  final ValueChanged<String> onKeyPress;

  /// When true, the digit grid is replaced by the locked-out overlay.
  final bool locked;

  /// Seconds remaining in the lockout, shown in the overlay's countdown
  /// text. Ignored unless [locked] is true.
  final int? lockSecondsRemaining;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LanternTokens>()!;
    final keySize = AppResponsive.isPortrait(context)
        ? AppResponsive.buttonSize(context) + AppResponsive.spacing(context, 16)
        : AppResponsive.buttonSize(context);
    final keypadWidth = (keySize * 3) + AppResponsive.spacing(context, 48);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDots(context, tokens),
        SizedBox(height: AppResponsive.spacing(context, 24)),
        if (locked)
          _buildLockedOverlay(context, tokens, keypadWidth)
        else
          _buildGrid(context, tokens, keySize),
      ],
    );
  }

  Widget _buildDots(BuildContext context, LanternTokens tokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalDigits, (index) {
        final filled = index < enteredLength;
        return Semantics(
          label: 'PIN digit ${index + 1} of $totalDigits, '
              '${filled ? "entered" : "empty"}',
          child: Container(
            margin: EdgeInsets.only(right: AppResponsive.spacing(context, 12)),
            width: AppResponsive.spacing(context, 20),
            height: AppResponsive.spacing(context, 20),
            decoration: BoxDecoration(
              color: filled ? tokens.lantern : tokens.hush,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLockedOverlay(
    BuildContext context,
    LanternTokens tokens,
    double keypadWidth,
  ) {
    return SizedBox(
      width: keypadWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_clock,
            size: AppResponsive.iconSize(context, 48),
            color: tokens.moonFaint,
          ),
          SizedBox(height: AppResponsive.spacing(context, 16)),
          Text(
            'Too many attempts.\nTry again in ${lockSecondsRemaining ?? 0}s.',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(color: tokens.moonDim),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, LanternTokens tokens, double keySize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeyRow(context, tokens, const ['1', '2', '3'], keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(context, tokens, const ['4', '5', '6'], keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(context, tokens, const ['7', '8', '9'], keySize),
        SizedBox(height: AppResponsive.spacing(context, 16)),
        _buildKeyRow(context, tokens, const ['', '0', 'DEL'], keySize),
      ],
    );
  }

  Widget _buildKeyRow(
    BuildContext context,
    LanternTokens tokens,
    List<String> keys,
    double keySize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return SizedBox(width: keySize, height: keySize);
        }

        return Semantics(
          label: key == 'DEL' ? 'Delete' : key,
          button: true,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.spacing(context, 8),
            ),
            child: GestureDetector(
              onTap: () => onKeyPress(key),
              child: Container(
                width: keySize,
                height: keySize,
                decoration: BoxDecoration(
                  color: tokens.nightCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.hush, width: 1),
                  boxShadow: AppShadows.card,
                ),
                alignment: Alignment.center,
                child: key == 'DEL'
                    ? Icon(
                        Icons.backspace_rounded,
                        size: AppResponsive.iconSize(context, 28),
                        color: tokens.moon,
                      )
                    : Text(
                        key,
                        style: AppTypography.keypadDigit.copyWith(
                          color: tokens.moon,
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
