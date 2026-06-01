/// Credit-card brand detection and per-brand metadata for `cmx_fields`.
library;

import 'package:flutter/material.dart';

/// The credit/debit card networks recognized by [CardTypeDetector].
enum CardType {
  /// The brand could not be determined from the entered prefix.
  unknown,

  /// Visa.
  visa,

  /// Mastercard.
  mastercard,

  /// American Express.
  amex,

  /// Discover.
  discover,

  /// RuPay (India).
  rupay,

  /// Maestro.
  maestro,
}

/// Pure, unit-testable helpers that detect a [CardType] from a card number and
/// expose per-brand metadata (display name, maximum digit length, CVV length).
///
/// Detection works on the *digits* of a number (any non-digit characters such
/// as the grouping spaces are ignored) by matching numeric prefixes and prefix
/// ranges, so partially typed numbers are classified as early as possible.
class CardTypeDetector {
  const CardTypeDetector._();

  /// Strips every non-digit character from [input], returning digits only.
  static String _digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Returns the integer value of the first [length] digits of [digits],
  /// right-padding with zeros when fewer digits are available so that range
  /// comparisons behave consistently for partial input.
  ///
  /// Returns `null` when [digits] is empty.
  static int? _prefix(String digits, int length) {
    if (digits.isEmpty) return null;
    final take = digits.length >= length
        ? digits.substring(0, length)
        : digits.padRight(length, '0');
    return int.tryParse(take);
  }

  /// Returns `true` when the leading digits of [digits] fall within the
  /// inclusive range [[low], [high]], both expressed with [length] digits.
  static bool _inRange(String digits, int length, int low, int high) {
    final value = _prefix(digits, length);
    if (value == null) return false;
    return value >= low && value <= high;
  }

  /// Detects the [CardType] for [number].
  ///
  /// [number] may contain spaces or other separators; only its digits are
  /// considered. Returns [CardType.unknown] for empty input or any prefix that
  /// matches no known network.
  ///
  /// Order matters: more specific networks (RuPay, Maestro, Discover) are
  /// checked before broader ones so overlapping prefixes resolve correctly.
  static CardType detect(String number) {
    final digits = _digitsOnly(number);
    if (digits.isEmpty) return CardType.unknown;

    // Amex: 34 / 37.
    if (_inRange(digits, 2, 34, 34) || _inRange(digits, 2, 37, 37)) {
      return CardType.amex;
    }

    // RuPay: 60, 6521, 6522, 508.
    if (_inRange(digits, 4, 6521, 6522) ||
        _inRange(digits, 3, 508, 508) ||
        (_inRange(digits, 2, 60, 60) &&
            // 6011 / 60110x-60119x belong to Discover, not RuPay.
            !_inRange(digits, 4, 6011, 6011))) {
      return CardType.rupay;
    }

    // Maestro: 50, 56-58, 6304, 6759, 676770, 676774.
    if (_inRange(digits, 2, 50, 50) ||
        _inRange(digits, 2, 56, 58) ||
        _inRange(digits, 4, 6304, 6304) ||
        _inRange(digits, 4, 6759, 6759) ||
        _inRange(digits, 6, 676770, 676770) ||
        _inRange(digits, 6, 676774, 676774)) {
      return CardType.maestro;
    }

    // Discover: 6011, 644-649, 65, 622126-622925.
    if (_inRange(digits, 4, 6011, 6011) ||
        _inRange(digits, 3, 644, 649) ||
        _inRange(digits, 2, 65, 65) ||
        _inRange(digits, 6, 622126, 622925)) {
      return CardType.discover;
    }

    // Mastercard: 51-55, 2221-2720.
    if (_inRange(digits, 2, 51, 55) || _inRange(digits, 4, 2221, 2720)) {
      return CardType.mastercard;
    }

    // Visa: starts with 4.
    if (_inRange(digits, 1, 4, 4)) return CardType.visa;

    return CardType.unknown;
  }

  /// A human-readable brand name for [type].
  static String displayName(CardType type) {
    switch (type) {
      case CardType.visa:
        return 'Visa';
      case CardType.mastercard:
        return 'Mastercard';
      case CardType.amex:
        return 'Amex';
      case CardType.discover:
        return 'Discover';
      case CardType.rupay:
        return 'RuPay';
      case CardType.maestro:
        return 'Maestro';
      case CardType.unknown:
        return 'Card';
    }
  }

  /// The maximum number of digits a [type]'s account number contains.
  ///
  /// Amex numbers are 15 digits; every other supported network is 16.
  static int maxLength(CardType type) => type == CardType.amex ? 15 : 16;

  /// The expected CVV/CID length for [type].
  ///
  /// Amex uses a 4-digit CID; every other supported network uses 3.
  static int cvvLength(CardType type) => type == CardType.amex ? 4 : 3;
}

const Map<CardType, Color> _brandColors = <CardType, Color>{
  CardType.visa: Color(0xFF1A1F71),
  CardType.mastercard: Color(0xFFEB001B),
  CardType.amex: Color(0xFF2E77BC),
  CardType.discover: Color(0xFFF26E21),
  CardType.rupay: Color(0xFF097D40),
  CardType.maestro: Color(0xFF0066B2),
  CardType.unknown: Color(0xFF9E9E9E),
};

const Map<CardType, String> _brandShortNames = <CardType, String>{
  CardType.visa: 'VISA',
  CardType.mastercard: 'MC',
  CardType.amex: 'AMEX',
  CardType.discover: 'DISC',
  CardType.rupay: 'RuPay',
  CardType.maestro: 'Maestro',
  CardType.unknown: 'CARD',
};

/// A small, asset-free brand badge for [type], drawn purely with Flutter
/// widgets (a rounded, brand-colored [Container] with the brand short-name).
///
/// [size] controls the badge height; its width adapts to the label.
Widget brandIcon(CardType type, {double size = 22}) {
  final color = _brandColors[type] ?? _brandColors[CardType.unknown]!;
  final label = _brandShortNames[type] ?? _brandShortNames[CardType.unknown]!;
  // Mastercard's iconic interlocking circles read better than text.
  if (type == CardType.mastercard) {
    return _MastercardBadge(size: size);
  }
  return Container(
    key: ValueKey<CardType>(type),
    height: size,
    padding: EdgeInsets.symmetric(horizontal: size * 0.28),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        height: 1,
      ),
    ),
  );
}

/// The interlocking-circles Mastercard badge, drawn with [CustomPaint].
class _MastercardBadge extends StatelessWidget {
  const _MastercardBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const ValueKey<CardType>(CardType.mastercard),
      size: Size(size * 1.45, size),
      painter: _MastercardPainter(),
    );
  }
}

class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final cy = size.height / 2;
    final left = Offset(size.width / 2 - r * 0.6, cy);
    final right = Offset(size.width / 2 + r * 0.6, cy);

    final redPaint = Paint()..color = const Color(0xFFEB001B);
    final yellowPaint = Paint()..color = const Color(0xFFF79E1B);
    canvas.drawCircle(left, r, redPaint);
    canvas.drawCircle(right, r, yellowPaint);

    // Overlap blend region.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(left, r, Paint()..color = const Color(0xFFEB001B));
    canvas.drawCircle(
      right,
      r,
      Paint()
        ..color = const Color(0xFFFF5F00)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MastercardPainter oldDelegate) => false;
}
