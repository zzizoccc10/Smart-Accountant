// ============================================================================
// نموذج الموظف — إضافة/تعديل
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';

class EmployeeForm extends StatefulWidget {
  final Employee? employee;
  const EmployeeForm({super.key, this.employee});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _code;
  late TextEditingController _job;
  late TextEditingController _dept;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _nationalId;
  late TextEditingController _basic;
  late TextEditingController _allowances;
  late TextEditingController _deductions;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _name = TextEditingController(text: e?.name ?? '');
    _code = TextEditingController(text: e?.code ?? '');
    _job = TextEditingController(text: e?.jobTitle ?? '');
    _dept = TextEditingController(text: e?.department ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _nationalId = TextEditingController(text: e?.nationalId ?? '');
    _basic = TextEditingController(
        text: (e?.basicSalary ?? 0) == 0 ? '' : e!.basicSalary.toString());
    _allowances = TextEditingController(
        text: (e?.allowances ?? 0) == 0 ? '' : e!.allowances.toString());
    _deductions = TextEditingController(
        text: (e?.deductions ?? 0) == 0 ? '' : e!.deductions.toString());
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _job.dispose();
    _dept.dispose();
    _phone.dispose();
    _email.dispose();
    _nationalId.dispose();
    _basic.dispose();
    _allowances.dispose();
    _deductions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<ERPProvider>();
    final emp = Employee(
      id: widget.employee?.id ?? AppDatabase.newId(),
      code: _code.text.trim(),
      name: _name.text.trim(),
      jobTitle: _job.text.trim(),
      department: _dept.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      nationalId: _nationalId.text.trim(),
      hireDate: widget.employee?.hireDate ?? '',
      basicSalary: double.tryParse(_basic.text) ?? 0,
      allowances: double.tryParse(_allowances.text) ?? 0,
      deductions: double.tryParse(_deductions.text) ?? 0,
      salaryAccountId: widget.employee?.salaryAccountId ?? '',
      isActive: _active,
      notes: widget.employee?.notes ?? '',
    );
    if (widget.employee == null) {
      await prov.addEmployee(emp);
    } else {
      await prov.updateEmployee(emp);
    }
    if (mounted) Navigator.pop(context, emp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'موظف جديد' : 'تعديل موظف'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم الموظف',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'الكود',
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nationalId,
                    decoration: const InputDecoration(
                      labelText: 'الرقم القومي',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _job,
                    decoration: const InputDecoration(labelText: 'المسمى الوظيفي'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dept,
                    decoration: const InputDecoration(labelText: 'القسم'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'الهاتف',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'البريد',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('الراتب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _basic,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الراتب الأساسي',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _allowances,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'البدلات'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _deductions,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الخصومات الثابتة'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('موظف نشط'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
