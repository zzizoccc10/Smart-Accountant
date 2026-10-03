// ============================================================================
// تفقيط المبالغ إلى كلمات عربية — لطباعة السندات والشيكات
// ============================================================================
class NumWords {
  static const _ones = [
    '', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة',
    'ستة', 'سبعة', 'ثمانية', 'تسعة',
  ];
  static const _teens = [
    'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر',
    'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر',
  ];
  static const _tens = [
    '', 'عشرة', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون',
    'ستون', 'سبعون', 'ثمانون', 'تسعون',
  ];
  static const _hundreds = [
    '', 'مئة', 'مئتان', 'ثلاثمئة', 'أربعمئة', 'خمسمئة',
    'ستمئة', 'سبعمئة', 'ثمانمئة', 'تسعمئة',
  ];

  /// تحويل عدد صحيح (حتى المليارات) إلى كلمات
  static String integer(int n) {
    if (n == 0) return 'صفر';
    if (n < 0) return 'سالب ${integer(-n)}';

    final parts = <String>[];
    final billions = n ~/ 1000000000;
    final millions = (n % 1000000000) ~/ 1000000;
    final thousands = (n % 1000000) ~/ 1000;
    final rest = n % 1000;

    if (billions > 0) {
      parts.add(_scale(billions, 'مليار', 'ملياران', 'مليارات'));
    }
    if (millions > 0) {
      parts.add(_scale(millions, 'مليون', 'مليونان', 'ملايين'));
    }
    if (thousands > 0) {
      parts.add(_scale(thousands, 'ألف', 'ألفان', 'آلاف'));
    }
    if (rest > 0) {
      parts.add(_three(rest));
    }
    return parts.join(' و');
  }

  static String _scale(int n, String one, String two, String many) {
    if (n == 1) return one;
    if (n == 2) return two;
    if (n >= 3 && n <= 10) return '${_three(n)} $many';
    return '${_three(n)} $one';
  }

  static String _three(int n) {
    final parts = <String>[];
    final h = n ~/ 100;
    final r = n % 100;
    if (h > 0) parts.add(_hundreds[h]);
    if (r > 0) {
      if (r < 10) {
        parts.add(_ones[r]);
      } else if (r < 20) {
        parts.add(_teens[r - 10]);
      } else {
        final t = r ~/ 10;
        final o = r % 10;
        if (o > 0) {
          parts.add('${_ones[o]} و${_tens[t]}');
        } else {
          parts.add(_tens[t]);
        }
      }
    }
    return parts.join(' و');
  }

  /// تفقيط مبلغ مالي — مثال: "خمسة وعشرون ريالاً فقط لا غير"
  static String money(double amount, String currencyLabel,
      {String subUnit = 'هللة'}) {
    final negative = amount < 0;
    final abs = amount.abs();
    final intPart = abs.floor();
    final fracPart = ((abs - intPart) * 100).round();

    final sb = StringBuffer();
    if (negative) sb.write('سالب ');
    sb.write(integer(intPart));
    if (currencyLabel.isNotEmpty) sb.write(' $currencyLabel');
    if (fracPart > 0) {
      sb.write(' و${integer(fracPart)} $subUnit');
    }
    sb.write(' فقط لا غير');
    return sb.toString();
  }
}
