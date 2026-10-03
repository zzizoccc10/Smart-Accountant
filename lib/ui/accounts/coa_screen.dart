// ============================================================================
// دليل الحسابات — شجرة الحسابات
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'account_form.dart';
import '../../services/quick_export.dart';

class CoaScreen extends StatefulWidget {
  const CoaScreen({super.key});

  @override
  State<CoaScreen> createState() => _CoaScreenState();
}

class _CoaScreenState extends State<CoaScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final all = prov.accounts;
    final filtered = _search.isEmpty
        ? all
        : all
            .where((a) =>
                a.name.contains(_search) || a.code.contains(_search))
            .toList();

    // بناء الشجرة: نعرض حسب المستوى
    final roots = filtered.where((a) => a.parentId == null).toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الحسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'مزامنة مع العملاء/الموردين/الصناديق/المخازن',
            onPressed: () async {
              final n = await prov.syncChartOfAccounts();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(n > 0
                        ? 'تمت المزامنة — تم تحديث $n عنصر'
                        : 'الدليل متزامن بالفعل'),
                    backgroundColor:
                        n > 0 ? AppColors.success : AppColors.info,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'تصدير دليل الحسابات Excel',
            onPressed: () => exportEntityExcel(context, 'accounts'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountForm()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الرمز...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                for (final r in roots) _buildNode(r, filtered, 0, prov),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
      Account acc, List<Account> all, int depth, ERPProvider prov) {
    final children = all.where((a) => a.parentId == acc.id).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final balance = prov.accountBalance(acc.id);
    final typeColor = _typeColor(acc.accountType);

    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(bottom: 6, right: depth * 16.0),
          child: ListTile(
            dense: true,
            onTap: acc.isLeaf
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AccountForm(account: acc)),
                    )
                : null,
            leading: Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            title: Text(
              '${acc.code} — ${acc.name}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: acc.isLeaf ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              _typeLabel(acc.accountType),
              style: TextStyle(fontSize: 11, color: typeColor),
            ),
            trailing: acc.isLeaf && balance != 0
                ? Text(
                    Fmt.money(balance.abs(), prov.currency),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
        ),
        for (final c in children) _buildNode(c, all, depth + 1, prov),
      ],
    );
  }

  Color _typeColor(String t) {
    return switch (t) {
      'asset' => AppColors.primary,
      'liability' => AppColors.danger,
      'equity' => AppColors.purple,
      'revenue' => AppColors.success,
      _ => AppColors.warning,
    };
  }

  String _typeLabel(String t) {
    return switch (t) {
      'asset' => 'أصول',
      'liability' => 'خصوم',
      'equity' => 'حقوق ملكية',
      'revenue' => 'إيرادات',
      _ => 'مصروفات',
    };
  }
}
