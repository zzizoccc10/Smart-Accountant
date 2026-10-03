// ============================================================================
// شاشة الإعدادات
// ============================================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
import 'settings/audit_log_screen.dart';
import 'settings/permissions_screen.dart';
import 'settings/notifications_screen.dart';
import 'contacts/contacts_import_screen.dart';
import '../services/backup_service.dart';

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
  late TextEditingController _taxNumber;
  late TextEditingController _crNumber;
  String? _logoBase64;
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
    _taxNumber = TextEditingController(
        text: AppDatabase.getSetting('taxNumber', ''));
    _crNumber = TextEditingController(
        text: AppDatabase.getSetting('crNumber', ''));
    _logoBase64 = AppDatabase.getSetting('companyLogo').isEmpty
        ? null
        : AppDatabase.getSetting('companyLogo');
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
    _taxNumber.dispose();
    _crNumber.dispose();
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
      'taxNumber': _taxNumber.text.trim(),
      'crNumber': _crNumber.text.trim(),
      'companyLogo': _logoBase64 ?? '',
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

  Future<void> _pickLogo() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.first.bytes;
      if (bytes == null) return;
      if (bytes.length > 400 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حجم الصورة كبير (الحد 400KB)'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      setState(() => _logoBase64 = base64Encode(bytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر اختيار الصورة: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
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
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _logoBase64 == null
                            ? const Icon(Icons.image_outlined,
                                color: Colors.grey)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(_logoBase64!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('شعار المنشأة (يظهر في الفاتورة)',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: const Text('اختيار صورة'),
                                ),
                                if (_logoBase64 != null) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _logoBase64 = null),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.danger),
                                    label: const Text('حذف'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taxNumber,
                    decoration: const InputDecoration(
                      labelText: 'الرقم الضريبي (VAT)',
                      prefixIcon: Icon(Icons.receipt_long),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _crNumber,
                    decoration: const InputDecoration(
                      labelText: 'السجل التجاري',
                      prefixIcon: Icon(Icons.badge),
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
                  leading: const Icon(Icons.history, color: AppColors.info),
                  title: const Text('سجل المراجعة'),
                  subtitle: Text('${prov.auditLogs.length} عملية مسجّلة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuditLogScreen()),
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
                  leading: const Icon(Icons.notifications_active,
                      color: AppColors.danger),
                  title: const Text('مركز الإشعارات'),
                  subtitle: Text(
                      '${prov.unreadNotifications} إشعار غير مقروء • ${prov.notifications.length} إجمالي'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_open, color: AppColors.info),
                  title: const Text('صلاحيات التطبيق'),
                  subtitle:
                      const Text('جهات الاتصال • التخزين • واتساب • SMS'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PermissionsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.contact_phone, color: AppColors.teal),
                  title: const Text('استيراد جهات الاتصال من الهاتف'),
                  subtitle:
                      const Text('إضافة العملاء والموردين من دفتر الهاتف'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ContactsImportScreen()),
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
                  leading: const Icon(Icons.backup, color: AppColors.success),
                  title: const Text('نسخة احتياطية (تصدير)'),
                  subtitle: const Text('حفظ كل البيانات في ملف JSON'),
                  onTap: () async {
                    final path = await BackupService.exportBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(path == null
                              ? 'تم تصدير النسخة الاحتياطية'
                              : 'حُفظت في: $path'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.share, color: AppColors.indigo),
                  title: const Text('مشاركة النسخة الاحتياطية'),
                  subtitle:
                      const Text('إرسال الملف عبر واتساب/البريد/درايف'),
                  onTap: () async {
                    final ok = await BackupService.shareBackup();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'تم تجهيز الملف للمشاركة'
                              : 'تعذّرت المشاركة'),
                          backgroundColor:
                              ok ? AppColors.success : AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: AppColors.info),
                  title: const Text('استعادة من نسخة احتياطية'),
                  subtitle: const Text('استرجاع البيانات من ملف JSON'),
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'استعادة نسخة احتياطية',
                      message:
                          'سيتم استبدال كل البيانات الحالية بالبيانات من الملف. هل أنت متأكد؟',
                    );
                    if (!ok) return;
                    final res = await BackupService.restoreBackup();
                    if (context.mounted) {
                      context.read<ERPProvider>().reload();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
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
