// ============================================================================
// وحدة الموارد البشرية — الموظفون، الحضور، الرواتب
// ============================================================================
import 'package:flutter/material.dart';
import '../../services/quick_export.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'employee_form.dart';
import 'attendance_screen.dart';
import 'payroll_screen.dart';

class HrHome extends StatefulWidget {
  const HrHome({super.key});

  @override
  State<HrHome> createState() => _HrHomeState();
}

class _HrHomeState extends State<HrHome> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final employees = prov.employees
        .where((e) =>
            _search.isEmpty ||
            e.name.contains(_search) ||
            e.jobTitle.contains(_search))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموارد البشرية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'تصدير الموظفين Excel',
            onPressed: () => exportEntityExcel(context, 'employees'),
          ),
        ],
      ),
      body: Column(
        children: [
          // إجراءات
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _actionBtn(
                  context,
                  Icons.person_add,
                  'موظف جديد',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmployeeForm()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.event_available,
                  'الحضور',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                  ),
                ),
                _actionBtn(
                  context,
                  Icons.request_page,
                  'الرواتب',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PayrollScreen()),
                  ),
                ),
              ],
            ),
          ),
          // ملخص
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'عدد الموظفين',
                    value: '${prov.employees.where((e) => e.isActive).length}',
                    icon: Icons.groups,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'رواتب هذا الشهر',
                    value: Fmt.money(prov.monthlyPayrollTotal, curr),
                    icon: Icons.account_balance_wallet,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث عن موظف...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: employees.isEmpty
                ? EmptyState(
                    message: 'لا يوجد موظفون — أضف موظفاً للبدء',
                    icon: Icons.groups_outlined,
                    actionLabel: 'إضافة موظف',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeForm()),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: employees.length,
                    itemBuilder: (_, i) {
                      final e = employees[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EmployeeForm(employee: e)),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              e.name.isNotEmpty ? e.name.characters.first : '؟',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(e.name,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            e.jobTitle.isEmpty ? 'بدون مسمى' : e.jobTitle,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Fmt.money(e.netSalary, curr),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.success,
                                ),
                              ),
                              if (!e.isActive)
                                const Text('غير نشط',
                                    style: TextStyle(
                                        fontSize: 10, color: AppColors.danger)),
                            ],
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

  Widget _actionBtn(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
