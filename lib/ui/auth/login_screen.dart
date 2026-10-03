// ============================================================================
// شاشة الدخول / إنشاء المالك الأول — LoginScreen
// ----------------------------------------------------------------------------
// • إن لم يوجد مستخدمون => وضع "إنشاء المالك".
// • إن وُجدوا => تسجيل دخول بالبريد (وكلمة المرور عند تفعيل السحابة).
// • تعمل محلياً بالكامل حتى بدون Firebase.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(SessionProvider session) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (!UserService.hasUsers) {
      // إنشاء المالك الأول
      await session.createOwner(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    // تسجيل دخول
    final ok = await session.signIn(_email.text.trim(), _password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'فشل تسجيل الدخول'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isSetup = !UserService.hasUsers;
    final users = UserService.all();

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          size: 56, color: AppColors.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'المحاسب السهل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSetup
                            ? 'إعداد حساب المالك'
                            : 'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (isSetup) ...[
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(
                            labelText: 'اسم المالك',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل الاسم'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'أدخل البريد';
                            }
                            if (!v.contains('@')) return 'بريد غير صالح';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'رقم الهاتف (اختياري)',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'أدخل البريد'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: session.cloudEnabled
                                ? 'كلمة المرور'
                                : 'كلمة المرور (اختياري محلياً)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        if (users.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('مستخدمون متاحون:',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: users.take(6).map((u) {
                              return ActionChip(
                                avatar: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    u.initials,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.white),
                                  ),
                                ),
                                label: Text('${u.name} (${u.role.labelAr})'),
                                onPressed: () {
                                  _email.text = u.email;
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: session.busy
                              ? null
                              : () => _submit(session),
                          icon: session.busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(isSetup
                                  ? Icons.check_circle_outline
                                  : Icons.login),
                          label: Text(isSetup
                              ? 'إنشاء الحساب والمتابعة'
                              : 'دخول'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (!session.cloudEnabled) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              'الوضع المحلي — السحابة غير مُفعّلة',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
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
