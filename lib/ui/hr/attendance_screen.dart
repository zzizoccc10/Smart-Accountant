// ============================================================================
// شاشة الحضور والانصراف اليومي
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/export_button.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _date = DateTime.now().toIso8601String().split('T')[0];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().split('T')[0]);
    }
  }

  Attendance? _recordFor(String employeeId) {
    final prov = context.read<ERPProvider>();
    try {
      return prov.attendance.firstWhere(
          (a) => a.employeeId == employeeId && a.date == _date);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setStatus(Employee e, String status) async {
    final prov = context.read<ERPProvider>();
    final existing = _recordFor(e.id);
    final rec = Attendance(
      id: existing?.id ?? AppDatabase.newId(),
      employeeId: e.id,
      employeeName: e.name,
      date: _date,
      status: status,
      overtimeHours: existing?.overtimeHours ?? 0,
    );
    await prov.saveAttendance(rec);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final employees = prov.employees.where((e) => e.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحضور والانصراف'),
        actions: [
          ExportButton(
            title: 'سجل الحضور — $_date',
            companyName: prov.companyName,
            filename: 'attendance_$_date',
            headers: const ['الموظف', 'التاريخ', 'الحالة', 'ساعات إضافية'],
            rows: [
              for (final e in employees)
                [
                  e.name,
                  _date,
                  _statusLabel(_recordFor(e.id)?.status ?? 'absent'),
                  Fmt.num(_recordFor(e.id)?.overtimeHours ?? 0),
                ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'تغيير التاريخ',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                Text('تاريخ الحضور: $_date',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: employees.isEmpty
                ? const EmptyState(
                    message: 'لا يوجد موظفون نشطون',
                    icon: Icons.groups_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: employees.length,
                    itemBuilder: (_, i) {
                      final e = employees[i];
                      final rec = _recordFor(e.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    child: const Icon(Icons.person,
                                        size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(e.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                  if (rec != null)
                                    _statusBadge(rec.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                children: _statusOptions()
                                    .map((s) => ChoiceChip(
                                          label: Text(s['label']!,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          selected: rec?.status == s['key'],
                                          onSelected: (_) =>
                                              _setStatus(e, s['key']!),
                                        ))
                                    .toList(),
                              ),
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

  Widget _statusBadge(String status) {
    final map = <String, List<Object>>{
      'present': ['حاضر', AppColors.success],
      'absent': ['غائب', AppColors.danger],
      'late': ['متأخر', AppColors.warning],
      'leave': ['إجازة', AppColors.info],
      'holiday': ['عطلة', AppColors.purple],
    };
    final v = map[status] ?? ['غير محدد', Colors.grey];
    return Badge2(v[0] as String, color: v[1] as Color);
  }

  List<Map<String, String>> _statusOptions() => [
        {'key': 'present', 'label': 'حاضر'},
        {'key': 'absent', 'label': 'غائب'},
        {'key': 'late', 'label': 'متأخر'},
        {'key': 'leave', 'label': 'إجازة'},
        {'key': 'holiday', 'label': 'عطلة'},
      ];

  String _statusLabel(String s) {
    return switch (s) {
      'present' => 'حاضر',
      'absent' => 'غائب',
      'late' => 'متأخر',
      'leave' => 'إجازة',
      'holiday' => 'عطلة',
      _ => 'غير محدد',
    };
  }
}
