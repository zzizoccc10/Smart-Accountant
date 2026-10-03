// ============================================================================
// شاشة الجداول الأساسية — الفروع / وحدات القياس / مراكز التكلفة / أسعار الصرف
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../data/app_database.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../../services/quick_export.dart';
import 'import_screen.dart';
import 'branch_form.dart';

class BasicTablesScreen extends StatelessWidget {
  const BasicTablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الجداول الأساسية'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'تصدير / استيراد',
              onSelected: (v) {
                switch (v) {
                  case 'branches':
                    exportEntityExcel(context, 'branches');
                    break;
                  case 'units':
                    exportEntityExcel(context, 'units');
                    break;
                  case 'center':
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'branches',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.storefront, color: AppColors.success),
                    title: Text('تصدير الفروع Excel'),
                  ),
                ),
                PopupMenuItem(
                  value: 'units',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.straighten, color: AppColors.success),
                    title: Text('تصدير الوحدات Excel'),
                  ),
                ),
                PopupMenuItem(
                  value: 'center',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.upload_file, color: AppColors.teal),
                    title: Text('مركز الاستيراد/التصدير'),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'الفروع', icon: Icon(Icons.storefront, size: 18)),
              Tab(text: 'الوحدات', icon: Icon(Icons.straighten, size: 18)),
              Tab(text: 'مراكز التكلفة', icon: Icon(Icons.account_tree, size: 18)),
              Tab(text: 'أسعار الصرف', icon: Icon(Icons.currency_exchange, size: 18)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BranchesTab(),
            _UnitsTab(),
            _CostCentersTab(),
            _ExchangeRatesTab(),
          ],
        ),
      ),
    );
  }
}

// ============================ الفروع ============================
class _BranchesTab extends StatelessWidget {
  const _BranchesTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.branches;
    return Scaffold(
      body: list.isEmpty
          ? const EmptyState(message: 'لا توجد فروع', icon: Icons.storefront)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final b = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, prov, b),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.storefront,
                          size: 18, color: AppColors.primary),
                    ),
                    title: Text(b.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'الكود: ${b.code}${b.phone.isNotEmpty ? ' • ${b.phone}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'حذف الفرع', message: 'حذف ${b.name}؟');
                        if (ok) await prov.deleteBranch(b.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_branch',
        onPressed: () => _edit(context, prov, null),
        icon: const Icon(Icons.add),
        label: const Text('فرع جديد'),
      ),
    );
  }

  void _edit(BuildContext context, ERPProvider prov, Branch? b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BranchForm(branch: b)),
    );
  }
}

// ============================ الوحدات ============================
class _UnitsTab extends StatelessWidget {
  const _UnitsTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.units;
    return Scaffold(
      body: list.isEmpty
          ? const EmptyState(message: 'لا توجد وحدات', icon: Icons.straighten)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final u = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, prov, u),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.info.withValues(alpha: 0.12),
                      child: Text(
                        u.symbol.isEmpty ? u.code : u.symbol,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.info),
                      ),
                    ),
                    title: Text(u.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'الكود: ${u.code} • المعامل: ${Fmt.num(u.conversionFactor)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'حذف الوحدة', message: 'حذف ${u.name}؟');
                        if (ok) await prov.deleteUnit(u.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_unit',
        onPressed: () => _edit(context, prov, null),
        icon: const Icon(Icons.add),
        label: const Text('وحدة جديدة'),
      ),
    );
  }

  void _edit(BuildContext context, ERPProvider prov, Unit? u) {
    final code = TextEditingController(text: u?.code ?? '');
    final name = TextEditingController(text: u?.name ?? '');
    final symbol = TextEditingController(text: u?.symbol ?? '');
    final factor =
        TextEditingController(text: (u?.conversionFactor ?? 1).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u == null ? 'وحدة جديدة' : 'تعديل وحدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'الكود (PCS)')),
              const SizedBox(height: 8),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 8),
              TextField(
                  controller: symbol,
                  decoration: const InputDecoration(labelText: 'الرمز')),
              const SizedBox(height: 8),
              TextField(
                  controller: factor,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'معامل التحويل للوحدة الأساسية')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final un = Unit(
                id: u?.id ?? AppDatabase.newId(),
                code: code.text.trim(),
                name: name.text.trim(),
                symbol: symbol.text.trim(),
                conversionFactor: double.tryParse(factor.text) ?? 1.0,
                isActive: u?.isActive ?? true,
              );
              if (u == null) {
                await prov.addUnit(un);
              } else {
                await prov.updateUnit(un);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ============================ مراكز التكلفة ============================
class _CostCentersTab extends StatelessWidget {
  const _CostCentersTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.costCenters;
    return Scaffold(
      body: list.isEmpty
          ? const EmptyState(
              message: 'لا توجد مراكز تكلفة', icon: Icons.account_tree)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final c = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, prov, c),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.purple.withValues(alpha: 0.12),
                      child: const Icon(Icons.account_tree,
                          size: 18, color: AppColors.purple),
                    ),
                    title: Text(c.name, style: const TextStyle(fontSize: 14)),
                    subtitle: Text('الكود: ${c.code}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'حذف مركز التكلفة',
                            message: 'حذف ${c.name}؟');
                        if (ok) await prov.deleteCostCenter(c.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_cc',
        onPressed: () => _edit(context, prov, null),
        icon: const Icon(Icons.add),
        label: const Text('مركز جديد'),
      ),
    );
  }

  void _edit(BuildContext context, ERPProvider prov, CostCenter? c) {
    final code = TextEditingController(text: c?.code ?? '');
    final name = TextEditingController(text: c?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? 'مركز تكلفة جديد' : 'تعديل مركز تكلفة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'الكود')),
            const SizedBox(height: 8),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final cc = CostCenter(
                id: c?.id ?? AppDatabase.newId(),
                code: code.text.trim(),
                name: name.text.trim(),
                isActive: c?.isActive ?? true,
              );
              if (c == null) {
                await prov.addCostCenter(cc);
              } else {
                await prov.updateCostCenter(cc);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ============================ أسعار الصرف ============================
class _ExchangeRatesTab extends StatelessWidget {
  const _ExchangeRatesTab();

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final list = prov.exchangeRates;
    return Scaffold(
      body: list.isEmpty
          ? const EmptyState(
              message: 'لا توجد أسعار صرف', icon: Icons.currency_exchange)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final r = list[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _edit(context, prov, r),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                      child: Text(
                        r.currencyCode,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.teal),
                      ),
                    ),
                    title: Text('1 ${r.currencyCode}',
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      'شراء: ${Fmt.num(r.buyRate)} • بيع: ${Fmt.num(r.sellRate)} • ${r.rateDate}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'حذف سعر الصرف',
                            message: 'حذف سعر ${r.currencyCode}؟');
                        if (ok) await prov.deleteExchangeRate(r.id);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_xr',
        onPressed: () => _edit(context, prov, null),
        icon: const Icon(Icons.add),
        label: const Text('سعر جديد'),
      ),
    );
  }

  void _edit(BuildContext context, ERPProvider prov, ExchangeRate? r) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final buy = TextEditingController(text: (r?.buyRate ?? 1).toString());
    final sell = TextEditingController(text: (r?.sellRate ?? 1).toString());
    final date = TextEditingController(text: r?.rateDate ?? today);
    String? currencyId = r?.currencyId ??
        (prov.currencies.isNotEmpty ? prov.currencies.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(r == null ? 'سعر صرف جديد' : 'تعديل سعر صرف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: currencyId,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  items: prov.currencies
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.code} — ${c.name}'),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => currencyId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: buy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر الشراء')),
                const SizedBox(height: 8),
                TextField(
                    controller: sell,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'سعر البيع')),
                const SizedBox(height: 8),
                TextField(
                    controller: date,
                    decoration:
                        const InputDecoration(labelText: 'التاريخ (YYYY-MM-DD)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (currencyId == null) return;
                final code =
                    prov.currencies.firstWhere((c) => c.id == currencyId).code;
                final rate = ExchangeRate(
                  id: r?.id ?? AppDatabase.newId(),
                  currencyId: currencyId!,
                  currencyCode: code,
                  rateDate: date.text.trim(),
                  buyRate: double.tryParse(buy.text) ?? 1.0,
                  sellRate: double.tryParse(sell.text) ?? 1.0,
                );
                if (r == null) {
                  await prov.addExchangeRate(rate);
                } else {
                  await prov.updateExchangeRate(rate);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
