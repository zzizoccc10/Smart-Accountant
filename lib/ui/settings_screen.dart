// ============================================================================
// شاشة الإعدادات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/erp_provider.dart';
import '../data/app_database.dart';
import '../theme/app_theme.dart';
import 'widgets/common.dart';
import 'settings/currencies_screen.dart';
import 'settings/security_screen.dart';
import 'settings/fiscal_close_screen.dart';
import 'settings/import_screen.dart';
import 'settings/basic_tables_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _address;
  late TextEditingController _tax;
  late TextEditingController _footer;
  late String _currency;
  bool _allowNegative = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<ERPProvider>();
    _name = TextEditingController(text: prov.companyName);
    _phone = TextEditingController(text: prov.companyPhone);
    _address = TextEditingController(text: prov.companyAddress);
    _tax = TextEditingController(
        text: AppDatabase.getSetting('taxRate', '15'));
    _footer = TextEditingController(text: prov.invoiceFooter);
    _currency = prov.currency;
    _allowNegative = prov.allowNegativeStock;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _tax.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prov = context.read<ERPProvider>();
    await prov.saveSettings({
      'companyName': _name.text.trim(),
      'companyPhone': _phone.text.trim(),
      'companyAddress': _address.text.trim(),
      'taxRate': _tax.text.trim(),
      'invoiceFooter': _footer.text.trim(),
      'currency': _currency,
      'allowNegativeStock': _allowNegative.toString(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ الإعدادات'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('بيانات المنشأة', icon: Icons.business),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنشأة',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'الهاتف',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: 'العملة',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ر.س', child: Text('ريال سعودي')),
                      DropdownMenuItem(value: 'ر.ي', child: Text('ريال يمني')),
                      DropdownMenuItem(value: 'ج.م', child: Text('جنيه مصري')),
                      DropdownMenuItem(value: 'د.إ', child: Text('درهم إماراتي')),
                      DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي')),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'ر.س'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('المحاسبة والضريبة', icon: Icons.calculate),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _tax,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نسبة الضريبة الافتراضية (%)',
                      prefixIcon: Icon(Icons.percent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _allowNegative,
                    onChanged: (v) => setState(() => _allowNegative = v),
                    title: const Text('السماح بالبيع بدون رصيد مخزون'),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('الفواتير', icon: Icons.receipt),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _footer,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'نص تذييل الفاتورة',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('الأدوات المتقدمة', icon: Icons.tune),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange,
                      color: AppColors.info),
                  title: const Text('العملات وأسعار الصرف'),
                  subtitle: Text('${prov.currencies.length} عملة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CurrenciesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock, color: AppColors.purple),
                  title: const Text('الأمان وقفل التطبيق'),
                  subtitle: Text(prov.pinEnabled ? 'مفعّل' : 'معطّل'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SecurityScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_busy,
                      color: AppColors.warning),
                  title: const Text('إقفال السنة المالية'),
                  subtitle: Text(
                    prov.fiscalYearClosed.isEmpty
                        ? 'لم يتم الإقفال'
                        : 'آخر سنة مقفلة: ${prov.fiscalYearClosed}',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FiscalCloseScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.table_chart, color: AppColors.success),
                  title: const Text('الجداول الأساسية'),
                  subtitle: Text(
                      '${prov.branches.length} فرع • ${prov.units.length} وحدة • ${prov.costCenters.length} مركز تكلفة • ${prov.exchangeRates.length} سعر صرف'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BasicTablesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.upload_file, color: AppColors.teal),
                  title: const Text('استيراد البيانات (Excel / CSV)'),
                  subtitle: const Text('استيراد الأصناف والعملاء والموردين'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ImportScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('البيانات', icon: Icons.storage),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: AppColors.danger),
                  title: const Text('إعادة تعيين البيانات'),
                  subtitle: const Text('حذف كل البيانات والبدء من جديد'),
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'إعادة تعيين',
                      message:
                          'سيتم حذف جميع الفواتير والقيود والأصناف وإعادة التهيئة. هل أنت متأكد؟',
                    );
                    if (ok && context.mounted) {
                      await AppDatabase.clearAll();
                      if (context.mounted) {
                        context.read<ERPProvider>().reload();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إعادة التعيين')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 40, color: AppColors.primary),
                  const SizedBox(height: 8),
                  const Text('المحاسب السهل',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('الإصدار 1.0.0',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('نظام محاسبي متكامل يعمل دون اتصال',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ الإعدادات'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
