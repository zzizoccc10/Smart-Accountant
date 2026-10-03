// ============================================================================
// شاشة الرواتب — مسير الرواتب الشهري
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  late String _period;

  @override
  void initState() {
    super.initState();
    _period = DateTime.now().toIso8601String().substring(0, 7);
  }

  Future<void> _runPayroll() async {
    final prov = context.read<ERPProvider>();
    final active = prov.employees.where((e) => e.isActive).toList();
    if (active.isEmpty) {
      _snack('لا يوجد موظفون نشطون', AppColors.danger);
      return;
    }
    // الموظفون الذين لم يُصرف لهم راتب هذا الشهر
    final pending = active
        .where((e) => !prov.payrolls
            .any((p) => p.employeeId == e.id && p.period == _period))
        .toList();
    if (pending.isEmpty) {
      _snack('تم صرف رواتب جميع الموظفين لهذا الشهر', AppColors.info);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'صرف الرواتب',
      message: 'سيتم صرف رواتب ${pending.length} موظف لشهر $_period',
      confirmText: 'صرف',
      confirmColor: AppColors.success,
    );
    if (!ok) return;

    final date = '$_period-28';
    for (final e in pending) {
      await prov.createPayroll(
        employee: e,
        period: _period,
        date: date,
        cashboxId: prov.cashboxes.isNotEmpty ? prov.cashboxes.first.id : null,
      );
    }
    if (mounted) _snack('تم صرف ${pending.length} راتب', AppColors.success);
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final list =
        prov.payrolls.where((p) => p.period == _period).toList().reversed.toList();
    final total = list.fold(0.0, (s, p) => s + p.netPay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرواتب'),
        actions: [
          ExportButton(
            title: 'مسير الرواتب — $_period',
            companyName: prov.companyName,
            filename: 'payroll_$_period',
            headers: const [
              'الموظف',
              'الأساسي',
              'البدلات',
              'الخصومات',
              'الصافي'
            ],
            rows: [
              for (final p in list)
                [
                  p.employeeName,
                  Fmt.num(p.basicSalary),
                  Fmt.num(p.allowances),
                  Fmt.num(p.deductions),
                  Fmt.num(p.netPay),
                ],
            ],
            totals: ['إجمالي الرواتب: ${Fmt.money(total, curr)}'],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse('$_period-01'),
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2100),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        setState(() => _period =
                            picked.toIso8601String().substring(0, 7));
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('شهر: $_period',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: _runPayroll,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('صرف'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'عدد المسيرات',
                    value: '${list.length}',
                    icon: Icons.receipt_long,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'إجمالي الرواتب',
                    value: Fmt.money(total, curr),
                    icon: Icons.payments,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    message: 'لا توجد رواتب مصروفة لهذا الشهر',
                    icon: Icons.request_page_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0x1A2E7D32),
                            child: Icon(Icons.payments,
                                color: AppColors.success),
                          ),
                          title: Text(p.employeeName,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            '${p.payrollNumber} • ${p.period}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            Fmt.money(p.netPay, curr),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
