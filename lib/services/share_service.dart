// ============================================================================
// خدمة المشاركة عبر واتساب / SMS / البريد / الاتصال — ShareService
// تستخدم روابط url_launcher (تعمل على Android والويب)
// ============================================================================
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  /// مشاركة نص عبر واتساب (رقم اختياري)
  static Future<bool> whatsapp(String text, {String? phone}) async {
    final base = phone == null || phone.isEmpty
        ? 'https://wa.me/?text='
        : 'https://wa.me/${_cleanPhone(phone)}?text=';
    return _launch('$base${Uri.encodeComponent(text)}');
  }

  /// إرسال SMS
  static Future<bool> sms(String text, {String? phone}) async {
    final p = phone == null ? '' : _cleanPhone(phone);
    return _launch('sms:$p?body=${Uri.encodeComponent(text)}');
  }

  /// إرسال بريد إلكتروني
  static Future<bool> email(String subject, String body, {String? to}) async {
    final addr = to == null ? '' : Uri.encodeComponent(to);
    return _launch(
      'mailto:$addr?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
  }

  /// اتصال هاتفي
  static Future<bool> call(String phone) async =>
      _launch('tel:${_cleanPhone(phone)}');

  static Future<bool> _launch(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _cleanPhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('0')) p = p.substring(1);
    // إضافة مفتاح اليمن الافتراضي إن لم يبدأ بـ +
    if (!p.startsWith('+') && p.length == 9) p = '967$p';
    return p.replaceAll('+', '');
  }
}
