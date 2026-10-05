// ============================================================================
// مفاتيح الدول — قائمة مختصرة مع اليمن كدولة افتراضية
// ============================================================================
class Country {
  final String name; // الاسم بالعربية
  final String dial; // مفتاح الدولة (+967)
  final String iso; // رمز الدولة (YE)
  final String flag; // علم تعبيري
  const Country(this.name, this.dial, this.iso, this.flag);
}

class Countries {
  /// اليمن هي الدولة الافتراضية
  static const Country defaultCountry = Country('اليمن', '+967', 'YE', '🇾🇪');

  static const List<Country> all = [
    Country('اليمن', '+967', 'YE', '🇾🇪'),
    Country('السعودية', '+966', 'SA', '🇸🇦'),
    Country('الإمارات', '+971', 'AE', '🇦🇪'),
    Country('عمان', '+968', 'OM', '🇴🇲'),
    Country('قطر', '+974', 'QA', '🇶🇦'),
    Country('الكويت', '+965', 'KW', '🇰🇼'),
    Country('البحرين', '+973', 'BH', '🇧🇭'),
    Country('الأردن', '+962', 'JO', '🇯🇴'),
    Country('مصر', '+20', 'EG', '🇪🇬'),
    Country('السودان', '+249', 'SD', '🇸🇩'),
    Country('العراق', '+964', 'IQ', '🇮🇶'),
    Country('سوريا', '+963', 'SY', '🇸🇾'),
    Country('لبنان', '+961', 'LB', '🇱🇧'),
    Country('فلسطين', '+970', 'PS', '🇵🇸'),
    Country('ليبيا', '+218', 'LY', '🇱🇾'),
    Country('تونس', '+216', 'TN', '🇹🇳'),
    Country('الجزائر', '+213', 'DZ', '🇩🇿'),
    Country('المغرب', '+212', 'MA', '🇲🇦'),
    Country('تركيا', '+90', 'TR', '🇹🇷'),
    Country('الولايات المتحدة', '+1', 'US', '🇺🇸'),
    Country('المملكة المتحدة', '+44', 'GB', '🇬🇧'),
    Country('الهند', '+91', 'IN', '🇮🇳'),
    Country('باكستان', '+92', 'PK', '🇵🇰'),
    Country('إندونيسيا', '+62', 'ID', '🇮🇩'),
    Country('ماليزيا', '+60', 'MY', '🇲🇾'),
    Country('الصين', '+86', 'CN', '🇨🇳'),
  ];

  /// إيجاد دولة من مفتاحها
  static Country? byDial(String dial) {
    for (final c in all) {
      if (c.dial == dial) return c;
    }
    return null;
  }

  /// دمج مفتاح الدولة مع الرقم المحلي (إزالة الأصفار البادئة)
  static String compose(String dial, String local) {
    var l = local.replaceAll(RegExp(r'[^0-9]'), '');
    while (l.startsWith('0')) {
      l = l.substring(1);
    }
    var d = dial.replaceAll('+', '');
    return '+$d$l';
  }

  /// فصل رقم دولي إلى (مفتاح، محلي)
  static (String dial, String local) split(String phone) {
    final p = phone.trim();
    if (!p.startsWith('+')) {
      // بلا مفتاح — اعتبره محلياً بالدولة الافتراضية
      return (defaultCountry.dial, p);
    }
    // أطول مفتاح مطابق
    Country? match;
    for (final c in all) {
      if (p.startsWith(c.dial)) {
        if (match == null || c.dial.length > match.dial.length) match = c;
      }
    }
    if (match == null) {
      return (defaultCountry.dial, p.replaceAll('+', ''));
    }
    return (match.dial, p.substring(match.dial.length));
  }
}
