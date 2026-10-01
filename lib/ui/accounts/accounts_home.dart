// ============================================================================
// وحدة الحسابات — الدليل، جهات الاتصال، الصناديق، السندات، المصروفات، القيود
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import 'coa_screen.dart';
import 'contacts_screen.dart';
import 'cashboxes_screen.dart';
import 'voucher_form.dart';
import 'expenses_screen.dart';
import 'journal_entries_screen.dart';

class AccountsHome extends StatelessWidget {
  const AccountsHome({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;

    final menu = [
      _MenuItem(Icons.account_tree, 'دليل الحسابات', AppColors.primary,
          () => const CoaScreen()),
      _MenuItem(Icons.people, 'العملاء والموردون', AppColors.info,
          () => const ContactsScreen()),
      _MenuItem(Icons.account_balance_wallet, 'الصناديق', AppColors.success,
          () => const CashboxesScreen()),
      _MenuItem(Icons.receipt, 'سند قبض', AppColors.teal,
          () => const VoucherForm(type: 'receipt')),
      _MenuItem(Icons.payments, 'سند صرف', AppColors.warning,
          () => const VoucherForm(type: 'payment')),
      _MenuItem(Icons.money_off, 'المصروفات', AppColors.danger,
          () => const ExpensesScreen()),
      _MenuItem(Icons.book, 'قيود اليومية', AppColors.purple,
          () => const JournalEntriesScreen()),
    ];

    return RefreshIndicator(
      onRefresh: () async => prov.reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'رصيد الصندوق',
                  value: Fmt.money(prov.cashBalance, curr),
                  icon: Icons.account_balance_wallet,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'الذمم المدينة',
                  value: Fmt.money(prov.totalReceivables, curr),
                  icon: Icons.call_received,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'الذمم الدائنة',
                  value: Fmt.money(prov.totalPayables, curr),
                  icon: Icons.call_made,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'عدد القيود',
                  value: '${prov.journals.length}',
                  icon: Icons.book,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle('الأدوات المحاسبية', icon: Icons.grid_view),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: menu
                .map((m) => _menuCard(context, m))
                .toList(),
          ),
          const SizedBox(height: 20),
          // آخر القيود
          SectionTitle(
            'آخر القيود',
            icon: Icons.history,
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const JournalEntriesScreen()),
              ),
              child: const Text('عرض الكل'),
            ),
          ),
          if (prov.journals.isEmpty)
            const EmptyState(
              message: 'لا توجد قيود بعد',
              icon: Icons.book_outlined,
            )
          else
            ...prov.journals.reversed.take(5).map(
                  (j) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.book, color: AppColors.purple),
                      title: Text(j.description,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${j.entryNumber} • ${j.date}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        Fmt.money(j.totalDebit, curr),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, _MenuItem m) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => m.builder()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(m.icon, color: m.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  final Widget Function() builder;
  _MenuItem(this.icon, this.title, this.color, this.builder);
}
