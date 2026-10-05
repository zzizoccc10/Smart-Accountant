// ============================================================================
// شاشة الأمان — تفعيل قفل PIN
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _enabled = false;
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prov = context.read<ERPProvider>();
    _enabled = prov.pinEnabled;
    _pin.text = prov.pin;
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prov = context.read<ERPProvider>();
    if (_enabled) {
      if (_pin.text.length < 4) {
        _snack('الرمز يجب أن يكون 4 أرقام على الأقل', AppColors.danger);
        return;
      }
      if (_pin.text != _confirm.text && _confirm.text.isNotEmpty) {
        _snack('الرمز غير متطابق', AppColors.danger);
        return;
      }
    }
    await prov.setPin(_enabled, _pin.text);
    if (mounted) {
      _snack('تم حفظ الإعدادات', AppColors.success);
      Navigator.pop(context);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const Text('تفعيل قفل التطبيق'),
              subtitle: const Text('طلب رمز PIN عند فتح التطبيق'),
              secondary: const Icon(Icons.lock, color: AppColors.primary),
            ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'رمز الدخول (PIN)',
                prefixIcon: Icon(Icons.password),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'تأكيد الرمز',
                prefixIcon: Icon(Icons.password),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppColors.info.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ملاحظة: الرمز يُخزَّن محلياً على الجهاز. عند نسيانه يلزم مسح بيانات التطبيق.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
