// ============================================================================
// خدمة جهات اتصال الهاتف — تحميل مع تخزين مؤقت لتسريع الفتح
// ============================================================================
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

class ContactsService {
  static List<fc.Contact>? _cache;
  static DateTime? _cacheTime;
  static const Duration _ttl = Duration(minutes: 10);

  static bool get hasCache => _cache != null;

  /// يُبطل التخزين المؤقت (عند الحاجة لتحديث الجهات)
  static void invalidate() {
    _cache = null;
    _cacheTime = null;
  }

  /// تحميل كل جهات الاتصال مع تخزين مؤقت
  static Future<List<fc.Contact>> load({bool force = false}) async {
    if (!force &&
        _cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _ttl) {
      return _cache!;
    }
    final list = await fc.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      withThumbnail: false,
      withGroups: false,
      withAccounts: false,
      sorted: true,
    );
    _cache = list;
    _cacheTime = DateTime.now();
    return list;
  }

  /// أفضل رقم صالح للجهة (يتجنّب الأرقام الفارغة ويستخدم المُطبّع عند اللزوم)
  static String? bestPhone(fc.Contact c) {
    for (final p in c.phones) {
      if (_digits(p.number).isNotEmpty) return p.number;
      if (_digits(p.normalizedNumber).isNotEmpty) return p.normalizedNumber;
    }
    return null;
  }

  /// جهات الاتصال التي تملك رقماً صالحاً فقط
  static List<fc.Contact> withValidPhone(List<fc.Contact> all) =>
      all.where((c) => bestPhone(c) != null).toList();

  static String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
}
