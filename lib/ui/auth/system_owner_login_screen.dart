// ============================================================================
// شاشة إنشاء/دخول مالك النظام — SystemOwnerLoginScreen
// ----------------------------------------------------------------------------
// • إن لم يكن مالك نظام مُنشأ → نموذج إنشاء (اسم مستخدم + كلمة مرور).
// • إن كان موجوداً → نموذج دخول.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart' show PasswordStrengthBar;
import '../system_owner/system_owner_dashboard.dart';

class SystemOwnerLoginScreen extends StatefulWidget {
  const SystemOwnerLoginScreen({super.key});

  @override
  State<SystemOwnerLoginScreen> createState() => _SystemOwnerLoginScreenState();
}

class _SystemOwnerLoginScreenState extends State<SystemOwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'مالك النظام');
  final _username = TextEditingController(text: 'admin');
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create(SessionProvider session) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await session.createSystemOwner(
      name: _name.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      email: _email.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SystemOwnerDashboard()),
      );
    } else {
      _snack(session.error ?? 'تعذّر الإنشاء', error: true);
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('مالك النظام'),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 52,
                          color: AppColors.purple,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'إنشاء حساب مالك النظام',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'مالك النظام هو المشرف الأعلى الذي يدير كل المنشآت '
                          'ويتحكّم بالتفعيل والصلاحيات.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'الاسم',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل الاسم'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().length < 3)
                              ? 'اسم المستخدم 3 أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني (اختياري)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'كلمة المرور 6 أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: 6),
                        PasswordStrengthBar(password: _password.text),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _obscure,
                          decoration: const InputDecoration(
                            labelText: 'تأكيد كلمة المرور',
                            prefixIcon: Icon(Icons.lock_reset),
                          ),
                          validator: (v) => (v != _password.text)
                              ? 'كلمتا المرور غير متطابقتين'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: session.busy
                                ? null
                                : () => _create(session),
                            icon: session.busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_user),
                            label: const Text('إنشاء ودخول لوحة التحكم'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'احفظ بيانات الدخول في مكان آمن — فهي تمنح تحكّماً كاملاً بالنظام.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
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
