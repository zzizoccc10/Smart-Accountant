// ============================================================================
// شاشة نسيت كلمة المرور — ForgotPasswordScreen
// ----------------------------------------------------------------------------
// تتيح:
//   • إرسال رابط إعادة التعيين عبر البريد (عند تفعيل السحابة).
//   • طلب تعديل كلمة المرور محلياً (يُسجَّل الطلب لمالك النظام/المنشأة).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../services/control_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialLogin;
  final bool isSystemOwner;

  const ForgotPasswordScreen({
    super.key,
    this.initialLogin = '',
    this.isSystemOwner = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _identifier;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(text: widget.initialLogin);
  }

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  /// إرسال رابط إعادة التعيين عبر البريد
  Future<void> _sendResetByEmail() async {
    final val = _identifier.text.trim();
    if (val.isEmpty || !val.contains('@')) {
      _snack('أدخل البريد الإلكتروني المرتبط بالحساب', error: true);
      return;
    }
    setState(() => _busy = true);
    final res = await AuthService.sendPasswordReset(val);
    setState(() => _busy = false);
    if (!mounted) return;
    if (res.success) {
      _showSuccess('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك: $val');
    } else {
      _snack(res.error ?? 'تعذّر الإرسال', error: true);
    }
  }

  /// طلب تعديل كلمة المرور محلياً (تسجيل الطلب لمالك النظام/المنشأة)
  Future<void> _requestLocalReset() async {
    final val = _identifier.text.trim();
    if (val.isEmpty) {
      _snack('أدخل اسم المستخدم أو البريد', error: true);
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionProvider>();
    try {
      final company = ControlService.companyByLogin(val);
      final user = UserService.byLogin(val);
      if (session.isSystemOwner) {
        // قاعدة بيانات مالك النظام
      }
      // سجّل طلب إعادة التعيين
      await UserService.logActivity(
        userId: '',
        userName: val,
        action: 'password_reset_request',
        details: widget.isSystemOwner
            ? 'طلب تعديل كلمة مرور مالك النظام'
            : (company != null
                ? 'طلب تعديل كلمة مرور منشأة: ${company.companyName}'
                : (user != null ? 'طلب تعديل كلمة مرور مستخدم: ${user.name}' : 'طلب غير معروف')),
      );
      if (!mounted) return;
      _showSuccess(
        'تم تسجيل طلبك. سيُعالَج من قِبل إدارة النظام '
        '(${company?.companyName ?? user?.name ?? val}).',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read,
            color: AppColors.success, size: 42),
        title: const Text('تم'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cloudOn = AuthService.isCloudAvailable;
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset,
                          size: 52, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'هل نسيت كلمة المرور؟',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل اسم المستخدم أو البريد الإلكتروني، واختر طريقة الاستعادة.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _identifier,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم أو البريد الإلكتروني',
                          prefixIcon: Icon(Icons.person_search),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _sendResetByEmail,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.email_outlined),
                          label: const Text('إرسال رابط إعادة التعيين بالبريد'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _requestLocalReset,
                        icon: const Icon(Icons.support_agent),
                        label: const Text('طلب تعديل كلمة المرور من الإدارة'),
                      ),
                      if (!cloudOn) ...[
                        const SizedBox(height: 12),
                        Text(
                          'ملاحظة: إعادة التعيين عبر البريد تحتاج تفعيل السحابة. '
                          'يمكنك استخدام «طلب تعديل من الإدارة» محلياً.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
