// ============================================================================
// نموذج الأصل الثابت — إضافة/تعديل/تخريد
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_database.dart';
import '../../models/models.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';

class AssetForm extends StatefulWidget {
  final FixedAsset? asset;
  const AssetForm({super.key, this.asset});

  @override
  State<AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends State<AssetForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _code;
  late TextEditingController _cost;
  late TextEditingController _salvage;
  late TextEditingController _life;
  late TextEditingController _notes;
  String _category = 'أجهزة كمبيوتر';
  String _accountCode = '';
  String _purchaseDate = '';
  bool _saving = false;

  final _categories = const [
    'أراضي',
    'مباني',
    'سيارات',
    'أثاث',
    'أجهزة كمبيوتر',
    'آلات ومعدات',
    'أخرى',
  ];

  // خريطة تصنيف -> كود حساب
  static const _catAccount = {
    'أراضي': '1-2-01',
    'مباني': '1-2-02',
    'سيارات': '1-2-03',
    'أثاث': '1-2-04',
    'أجهزة كمبيوتر': '1-2-05',
    'آلات ومعدات': '1-2-05',
    'أخرى': '1-2-05',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.asset;
    _name = TextEditingController(text: a?.name ?? '');
    _code = TextEditingController(text: a?.code ?? '');
    _cost = TextEditingController(
        text: (a?.cost ?? 0) == 0 ? '' : a!.cost.toString());
    _salvage = TextEditingController(
        text: (a?.salvageValue ?? 0) == 0 ? '' : a!.salvageValue.toString());
    _life = TextEditingController(text: (a?.usefulLifeYears ?? 5).toString());
    _notes = TextEditingController(text: a?.notes ?? '');
    _category = a?.category ?? 'أجهزة كمبيوتر';
    _accountCode = a?.assetAccountCode ?? _catAccount[_category]!;
    _purchaseDate = a?.purchaseDate ??
        DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _cost.dispose();
    _salvage.dispose();
    _life.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_purchaseDate) ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() =>
          _purchaseDate = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final prov = context.read<ERPProvider>();
    final isNew = widget.asset == null;
    final asset = FixedAsset(
      id: widget.asset?.id ?? AppDatabase.newId(),
      code: _code.text.trim(),
      name: _name.text.trim(),
      category: _category,
      purchaseDate: _purchaseDate,
      cost: double.tryParse(_cost.text) ?? 0,
      salvageValue: double.tryParse(_salvage.text) ?? 0,
      usefulLifeYears: int.tryParse(_life.text) ?? 5,
      accumulatedDepreciation: widget.asset?.accumulatedDepreciation ?? 0,
      assetAccountCode: _accountCode,
      method: widget.asset?.method ?? 'straight_line',
      status: widget.asset?.status ?? 'active',
      disposalAmount: widget.asset?.disposalAmount ?? 0,
      disposalDate: widget.asset?.disposalDate ?? '',
      notes: _notes.text.trim(),
    );

    if (isNew) {
      await prov.addFixedAsset(asset);
    } else {
      await prov.updateFixedAsset(asset);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _disposeAsset() async {
    final prov = context.read<ERPProvider>();
    final curr = prov.currency;
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تخريد الأصل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'القيمة الدفترية الحالية: ${Fmt.money(widget.asset!.bookValue, curr)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مبلغ البيع (0 = استبعاد بدون بيع)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text) ?? 0),
            child: const Text('تأكيد التخريد'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    await prov.disposeAsset(assetId: widget.asset!.id, saleAmount: amount);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تخريد الأصل وإنشاء القيد المحاسبي')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final isNew = widget.asset == null;
    final disposed = widget.asset?.status == 'disposed';

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'أصل جديد' : 'تعديل أصل'),
        actions: [
          if (!isNew && !disposed)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'تخريد',
              onPressed: _disposeAsset,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الأصل *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              decoration: const InputDecoration(
                  labelText: 'الكود', hintText: 'مثال: FA-001'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'التصنيف'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _category = v;
                  _accountCode = _catAccount[v] ?? '1-2-05';
                });
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الشراء',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(_purchaseDate),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'التكلفة *'),
                    validator: (v) {
                      final d = double.tryParse(v ?? '');
                      if (d == null || d <= 0) return 'مطلوب';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salvage,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'القيمة التخريدية'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _life,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'العمر الإنتاجي (سنوات)'),
              validator: (v) {
                final d = int.tryParse(v ?? '');
                if (d == null || d <= 0) return 'أدخل رقماً موجباً';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            // معاينة الأقساط
            if (double.tryParse(_cost.text) != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'القسط الشهري: ${Fmt.money(_previewMonthly(), curr)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'القسط السنوي: ${Fmt.money(_previewAnnual(), curr)}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                    if (!isNew) ...[
                      const SizedBox(height: 4),
                      Text(
                        'مجمع الإهلاك الحالي: ${Fmt.money(widget.asset!.accumulatedDepreciation, curr)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        'القيمة الدفترية: ${Fmt.money(widget.asset!.bookValue, curr)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  double _previewAnnual() {
    final cost = double.tryParse(_cost.text) ?? 0;
    final salvage = double.tryParse(_salvage.text) ?? 0;
    final life = int.tryParse(_life.text) ?? 5;
    if (life <= 0) return 0;
    return (cost - salvage) / life;
  }

  double _previewMonthly() => _previewAnnual() / 12;
}
