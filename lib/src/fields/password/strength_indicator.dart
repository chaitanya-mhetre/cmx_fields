import 'package:flutter/widgets.dart';

import '../../core/cmx_animations.dart';

/// A qualitative measure of how resistant a password is to guessing.
///
/// Ordered from weakest ([none]) to strongest ([veryStrong]); the enum's
/// natural [index] is therefore also its severity rank.
enum PasswordStrength {
  /// No password entered.
  none,

  /// A very short / trivially guessable password.
  weak,

  /// A moderately long password with little variety.
  medium,

  /// A reasonably long password mixing letters and numbers.
  strong,

  /// A long password mixing upper/lower case, numbers and symbols.
  veryStrong;

  /// Human-readable label for this strength level.
  ///
  /// Returns the empty string for [none] so it renders nothing.
  String get label {
    switch (this) {
      case PasswordStrength.none:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  /// The indicative color for this strength level.
  ///
  /// Grey for [none], red for [weak], orange for [medium], amber for [strong]
  /// and green for [veryStrong].
  Color get color {
    switch (this) {
      case PasswordStrength.none:
        return const Color(0xFFBDBDBD); // grey 400
      case PasswordStrength.weak:
        return const Color(0xFFE53935); // red 600
      case PasswordStrength.medium:
        return const Color(0xFFFB8C00); // orange 600
      case PasswordStrength.strong:
        return const Color(0xFFFFB300); // amber 600
      case PasswordStrength.veryStrong:
        return const Color(0xFF43A047); // green 600
    }
  }
}

/// A single named password requirement together with its test predicate.
///
/// Used to drive the [PasswordRulesChecklist] and to compose custom rule sets.
@immutable
class PasswordRule {
  /// Creates a password rule with a human-readable [label] and a [test] that
  /// returns `true` when the candidate password satisfies the rule.
  const PasswordRule(this.label, this.test);

  /// Human-readable description of the requirement (e.g. "At least 8
  /// characters").
  final String label;

  /// Predicate evaluated against a candidate password; `true` when satisfied.
  final bool Function(String password) test;
}

/// The default set of password rules used when none is supplied.
///
/// Covers length (>= 8), an uppercase letter, a lowercase letter, a number and
/// a special character.
const List<PasswordRule> kDefaultPasswordRules = <PasswordRule>[
  PasswordRule('At least 8 characters', _hasMinLength),
  PasswordRule('An uppercase letter', _hasUppercase),
  PasswordRule('A lowercase letter', _hasLowercase),
  PasswordRule('A number', _hasNumber),
  PasswordRule('A special character', _hasSpecial),
];

bool _hasMinLength(String value) => value.length >= 8;
bool _hasUppercase(String value) => value.contains(RegExp('[A-Z]'));
bool _hasLowercase(String value) => value.contains(RegExp('[a-z]'));
bool _hasNumber(String value) => value.contains(RegExp('[0-9]'));
bool _hasSpecial(String value) =>
    value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\/~`+=;]'));

/// Computes a [PasswordStrength] for a candidate password.
class PasswordStrengthChecker {
  const PasswordStrengthChecker._();

  /// Classifies [password] into a [PasswordStrength].
  ///
  /// Rules, in order of decreasing strength:
  /// * [PasswordStrength.none] — empty.
  /// * [PasswordStrength.veryStrong] — length >= 8 with an uppercase letter, a
  ///   lowercase letter, a number and a symbol.
  /// * [PasswordStrength.strong] — length >= 8 with at least one letter and one
  ///   number.
  /// * [PasswordStrength.medium] — length >= 6.
  /// * [PasswordStrength.weak] — anything shorter (length < 6).
  static PasswordStrength check(String password) {
    if (password.isEmpty) return PasswordStrength.none;

    final hasUpper = password.contains(RegExp('[A-Z]'));
    final hasLower = password.contains(RegExp('[a-z]'));
    final hasLetter = password.contains(RegExp('[a-zA-Z]'));
    final hasNumber = password.contains(RegExp('[0-9]'));
    final hasSymbol = _hasSpecial(password);

    if (password.length >= 8 &&
        hasUpper &&
        hasLower &&
        hasNumber &&
        hasSymbol) {
      return PasswordStrength.veryStrong;
    }
    if (password.length >= 8 && hasLetter && hasNumber) {
      return PasswordStrength.strong;
    }
    if (password.length >= 6) {
      return PasswordStrength.medium;
    }
    return PasswordStrength.weak;
  }
}

/// A horizontal four-segment bar that fills left-to-right according to a
/// [PasswordStrength], with the strength's label beneath it.
///
/// Each filled segment animates its color smoothly (honoring reduced motion by
/// collapsing the animation to zero duration).
class StrengthIndicator extends StatelessWidget {
  /// Creates a strength indicator for the given [strength].
  const StrengthIndicator({
    super.key,
    required this.strength,
    this.showLabel = true,
    this.labelStyle,
  });

  /// The strength to visualize.
  final PasswordStrength strength;

  /// Whether to render the textual strength label below the bar.
  final bool showLabel;

  /// Optional style override for the strength label text.
  final TextStyle? labelStyle;

  /// The number of filled segments for a given [PasswordStrength].
  int get _filledSegments {
    switch (strength) {
      case PasswordStrength.none:
        return 0;
      case PasswordStrength.weak:
        return 1;
      case PasswordStrength.medium:
        return 2;
      case PasswordStrength.strong:
        return 3;
      case PasswordStrength.veryStrong:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = CmxAnimations.reduceMotion(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 280);
    final filled = _filledSegments;
    const inactiveColor = Color(0xFFE0E0E0); // grey 300

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < 4; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < filled ? strength.color : inactiveColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showLabel) ...<Widget>[
          const SizedBox(height: 6),
          AnimatedDefaultTextStyle(
            duration: duration,
            curve: Curves.easeOut,
            style: (labelStyle ?? const TextStyle(fontSize: 12)).copyWith(
              color: strength == PasswordStrength.none
                  ? const Color(0xFF9E9E9E)
                  : strength.color,
              fontWeight: FontWeight.w500,
            ),
            child: Text(
              strength.label.isEmpty ? ' ' : strength.label,
            ),
          ),
        ],
      ],
    );
  }
}

/// A vertical checklist rendering each [PasswordRule] with a [CmxCheckmark]
/// when met, or a muted dot when unmet.
///
/// Recomputes against [password] on every rebuild so it animates as rules are
/// satisfied.
class PasswordRulesChecklist extends StatelessWidget {
  /// Creates a rules checklist for [rules] evaluated against [password].
  const PasswordRulesChecklist({
    super.key,
    required this.rules,
    required this.password,
    this.metColor = const Color(0xFF43A047),
    this.unmetColor = const Color(0xFF9E9E9E),
    this.textStyle,
  });

  /// The rules to display.
  final List<PasswordRule> rules;

  /// The candidate password each rule is tested against.
  final String password;

  /// Color of the checkmark / text for a satisfied rule.
  final Color metColor;

  /// Color of the dot / text for an unsatisfied rule.
  final Color unmetColor;

  /// Optional style override for each rule's label.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final reduce = CmxAnimations.reduceMotion(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 200);
    final baseStyle = textStyle ?? const TextStyle(fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final rule in rules)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: rule.test(password)
                      ? CmxCheckmark(
                          visible: true,
                          color: metColor,
                          size: 16,
                          strokeWidth: 2,
                        )
                      : Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: unmetColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOut,
                    style: baseStyle.copyWith(
                      color: rule.test(password) ? metColor : unmetColor,
                    ),
                    child: Text(rule.label),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
