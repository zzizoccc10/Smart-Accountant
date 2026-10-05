// ============================================================================
// شاشة الدخول الرئيسية — LoginScreen
// ----------------------------------------------------------------------------
// تحوي زرّين في الأعلى:
//   1) دخول المنشأة/المستخدم (مُفعّل افتراضياً) — اسم مستخدم/بريد + كلمة مرور.
//   2) مالك النظام — يفتح واجهة مالك النظام (اسم مستخدم + كلمة مرور) → لوحة التحكم.
//
// وأسفل النموذج:
//   • نسيت كلمة المرور (طلب تعديل).
//   • إنشاء حساب جديد (منشأة).
//   • الدخول عبر حساب Google.
//   • الدخول بدون حساب (زائر).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/security_service.dart';
import '../../theme/app_theme.dart';
import '../system_owner/system_owner_dashboard.dart';
import 'forgot_password_screen.dart';
import 'register_company_screen.dart';
import 'system_owner_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 'company' = دخول المنشأة/المستخدم (الافتراضي) | 'owner' = مالك النظام
  String _tab = 'company';

  final _companyFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();

  final _login = TextEditingController(); // اسم مستخدم أو بريد
  final _password = TextEditingController();
  final _ownerUser = TextEditingController();
  final _ownerPass = TextEditingController();

  bool _obscure = true;
  bool _obscureOwner = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _ownerUser.dispose();
    _ownerPass.dispose();
    super.dispose();
  }

  Future<void> _submitCompany(SessionProvider session) async {
    if (!_companyFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await session.signInCompany(_login.text.trim(), _password.text);
    if (!mounted) return;
    if (ok) {
      _goToApp();
    } else {
      _snack(session.error ?? 'فشل تسجيل الدخول', error: true);
    }
  }

  Future<void> _submitOwner(SessionProvider session) async {
    // إن لم يُنشأ مالك النظام بعد → افتح شاشة الإنشاء
    if (!session.hasSystemOwner) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SystemOwnerLoginScreen()),
      );
      if (created == true && mounted) _goOwnerDashboard();
      return;
    }
    if (!_ownerFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await session.signInSystemOwner(
      _ownerUser.text.trim(),
      _ownerPass.text,
    );
    if (!mounted) return;
    if (ok) {
      _goOwnerDashboard();
    } else {
      _snack(session.error ?? 'فشل دخول مالك النظام', error: true);
    }
  }

  void _goToApp() {
    // العودة إلى SplashScreen الذي يوجّه للتطبيق
    Navigator.of(context).pop(true);
  }

  void _goOwnerDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SystemOwnerDashboard()),
    );
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
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- الشعار ----------
                      const Icon(Icons.account_balance_wallet_rounded,
                          size: 52, color: AppColors.primary),
                      const SizedBox(height: 8),
                      const Text(
                        'المحاسب السهل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---------- الزرّان العلويان ----------
                      _modeToggle(),
                      const SizedBox(height: 20),

                      // ---------- نموذج الدخول ----------
                      if (_tab == 'company')
                        _companyForm(session)
                      else
                        _ownerForm(session),

                      const SizedBox(height: 16),

                      // ---------- نسيت كلمة المرور ----------
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  initialLogin: _login.text.trim(),
                                  isSystemOwner: _tab == 'owner',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.help_outline, size: 18),
                          label: const Text('نسيت كلمة المرور؟'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ),

                      const Divider(height: 24),

                      // ---------- إنشاء حساب جديد ----------
                      OutlinedButton.icon(
                        onPressed: session.busy
                            ? null
                            : () async {
                                final ok = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const RegisterCompanyScreen(),
                                  ),
                                );
                                if (ok == true && mounted) _goToApp();
                              },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('إنشاء حساب جديد'),
                      ),
                      const SizedBox(height: 10),

                      // ---------- الدخول عبر Google ----------
                      OutlinedButton.icon(
                        onPressed: session.busy
                            ? null
                            : () => _googleSignIn(session),
                        icon: const _GoogleLogo(),
                        label: const Text('المتابعة باستخدام حساب Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ---------- الدخول بدون حساب ----------
                      TextButton.icon(
                        onPressed: session.busy
                            ? null
                            : () async {
                                await session.continueAsGuest();
                                if (mounted) _goToApp();
                              },
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: const Text('الدخول بدون حساب (استكشاف)'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),

                      // ---------- مؤشر حالة السحابة ----------
                      if (!session.cloudEnabled) ...[
                        const SizedBox(height: 8),
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

  // --------------------------------------------------------------------------
  // الزرّان العلويان (Toggle)
  // --------------------------------------------------------------------------
  Widget _modeToggle() {
    Widget btn({
      required String id,
      required IconData icon,
      required String label,
    }) {
      final active = _tab == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? AppColors.primary : Colors.grey.shade300,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 22, color: active ? Colors.white : Colors.grey.shade700),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(
          id: 'company',
          icon: Icons.storefront_rounded,
          label: 'منشأة / مستخدم',
        ),
        const SizedBox(width: 10),
        btn(
          id: 'owner',
          icon: Icons.admin_panel_settings_rounded,
          label: 'مالك النظام',
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // نموذج الدخول (منشأة/مستخدم)
  // --------------------------------------------------------------------------
  Widget _companyForm(SessionProvider session) {
    return Form(
      key: _companyFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _login,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم أو البريد الإلكتروني',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'أدخل اسم المستخدم أو البريد'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onFieldSubmitted: (_) => _submitCompany(session),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: session.busy ? null : () => _submitCompany(session),
              icon: session.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login),
              label: const Text('دخول'),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // نموذج مالك النظام
  // --------------------------------------------------------------------------
  Widget _ownerForm(SessionProvider session) {
    return Form(
      key: _ownerFormKey,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings,
                    color: AppColors.purple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.hasSystemOwner
                        ? 'دخول مالك النظام إلى لوحة التحكم'
                        : 'لم يُنشأ مالك النظام بعد — سيُطلب إنشاؤه',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (session.hasSystemOwner) ...[
            TextFormField(
              controller: _ownerUser,
              decoration: const InputDecoration(
                labelText: 'اسم مستخدم مالك النظام',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل اسم المستخدم' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ownerPass,
              obscureText: _obscureOwner,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureOwner ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureOwner = !_obscureOwner),
                ),
              ),
              onFieldSubmitted: (_) => _submitOwner(session),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: session.busy ? null : () => _submitOwner(session),
              icon: session.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login),
              label: Text(session.hasSystemOwner
                  ? 'دخول لوحة التحكم'
                  : 'إنشاء مالك النظام'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // الدخول عبر Google
  // --------------------------------------------------------------------------
  Future<void> _googleSignIn(SessionProvider session) async {
    final res = await session.signInWithGoogleAndEnter();
    if (!mounted) return;
    if (res) {
      _goToApp();
    } else {
      _snack(session.error ?? 'تعذّر الدخول عبر Google', error: true);
    }
  }
}

/// شعار Google المصغّر (G ملوّن نصّي بسيط)
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

/// زر قوة كلمة المرور (يُستخدم في شاشات التسجيل)
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final score = SecurityService.strength(password);
    final colors = [
      Colors.grey.shade300,
      AppColors.danger,
      AppColors.warning,
      AppColors.info,
      AppColors.success,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                decoration: BoxDecoration(
                  color: i < score ? colors[score] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'قوة كلمة المرور: ${SecurityService.strengthLabel(score)}',
          style: TextStyle(fontSize: 11, color: colors[score]),
        ),
      ],
    );
  }
}
