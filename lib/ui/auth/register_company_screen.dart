// ============================================================================
// شاشة إنشاء حساب منشأة جديد — RegisterCompanyScreen
// ----------------------------------------------------------------------------
// خطوات التهيئة الأولية: بيانات المنشأة + بيانات الدخول الرئيسية.
// ينشئ CompanyAccount (اسم مستخدم + كلمة مرور + بريد) ويدخل مباشرة.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart' show PasswordStrengthBar;

class RegisterCompanyScreen extends StatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  State<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends State<RegisterCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyName = TextEditingController();
  final _ownerName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _companyName.dispose();
    _ownerName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(SessionProvider session) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await session.registerCompany(
      companyName: _companyName.text.trim(),
      ownerName: _ownerName.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
      email: _email.text.trim(),
      phone: _phone.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'تعذّر إنشاء الحساب'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب منشأة جديد')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.add_business,
                            size: 48, color: AppColors.primary),
                        const SizedBox(height: 8),
                        const Text('بيانات المنشأة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('أنشئ حساب منشأتك للبدء بالعمل',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 18),

                        TextFormField(
                          controller: _companyName,
                          decoration: const InputDecoration(
                            labelText: 'اسم المنشأة',
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل اسم المنشأة'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ownerName,
                          decoration: const InputDecoration(
                            labelText: 'اسم صاحب المنشأة',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل الاسم'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(),
                        ),
                        const Text('بيانات الدخول الرئيسية',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'تُستخدم هذه البيانات للدخول إلى التطبيق وإدارة مستخدمي منشأتك.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _username,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'اسم المستخدم 3 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني (اختياري — للاستعادة)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (!v.contains('@')) return 'بريد غير صالح';
                            return null;
                          },
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
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'كلمة المرور 6 أحرف على الأقل';
                            }
                            return null;
                          },
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
                            onPressed:
                                session.busy ? null : () => _submit(session),
                            icon: session.busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('إنشاء الحساب والدخول'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'بإنشاء الحساب أنت توافق على استخدام التطبيق لأغراضك التجارية.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
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
