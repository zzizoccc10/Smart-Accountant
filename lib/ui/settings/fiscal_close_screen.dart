// ============================================================================
// شاشة إقفال السنة المالية
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class FiscalCloseScreen extends StatefulWidget {
  const FiscalCloseScreen({super.key});

  @override
  State<FiscalCloseScreen> createState() => _FiscalCloseScreenState();
}

class _FiscalCloseScreenState extends State<FiscalCloseScreen> {
  late int _year;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year - 1;
  }

  double _revenue(ERPProvider prov) {
    final bals = prov.accountBalances();
    double r = 0;
    for (final a in prov.accounts) {
      if (a.accountType == 'revenue' && a.isLeaf) {
        final b = bals[a.id];
        if (b != null) r += (b['credit'] ?? 0) - (b['debit'] ?? 0);
      }
    }
    return r;
  }

  double _expense(ERPProvider prov) {
    final bals = prov.accountBalances();
    double e = 0;
    for (final a in prov.accounts) {
      if (a.accountType == 'expense' && a.isLeaf) {
        final b = bals[a.id];
        if (b != null) e += (b['debit'] ?? 0) - (b['credit'] ?? 0);
      }
    }
    return e;
  }

  Future<void> _close() async {
    final prov = context.read<ERPProvider>();
    final ok = await confirmDialog(
      context,
      title: 'إقفال السنة المالية',
      message:
          'سيتم ترحيل صافي الربح/الخسارة للسنة $_year إلى الأرباح المحتجزة.\nتأكد من إنهاء كل عمليات السنة قبل المتابعة.',
      confirmText: 'إقفال',
      confirmColor: AppColors.warning,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await prov.closeFiscalYear('$_year');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إقفال السنة المالية بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final rev = _revenue(prov);
    final exp = _expense(prov);
    final profit = rev - exp;
    final closed = prov.fiscalYearClosed;

    return Scaffold(
      appBar: AppBar(title: const Text('إقفال السنة المالية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _year,
            decoration: const InputDecoration(
              labelText: 'السنة المالية',
              prefixIcon: Icon(Icons.calendar_month),
            ),
            items: List.generate(10, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('إجمالي الإيرادات', Fmt.money(rev, curr),
                      AppColors.success),
                  const Divider(),
                  _row('إجمالي المصروفات', Fmt.money(exp, curr),
                      AppColors.danger),
                  const Divider(),
                  _row(
                    profit >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                    Fmt.money(profit.abs(), curr),
                    profit >= 0 ? AppColors.success : AppColors.danger,
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (closed.isNotEmpty)
            Card(
              color: AppColors.info.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.info),
                    const SizedBox(width: 12),
                    Text('تم إقفال سنة: $closed',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            color: AppColors.warning.withValues(alpha: 0.08),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الإقفال يترحل صافي الربح/الخسارة إلى الأرباح المحتجزة. لا يمكن التراجع عنه بسهولة.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
              ),
              onPressed: _busy ? null : _close,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_clock),
              label: const Text('إقفال السنة المالية'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
