// ============================================================================
// شاشة العملاء والموردين
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';
import '../contacts/contact_form.dart';
import 'contact_statement_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  int _tab = 0; // 0=all, 1=customers, 2=suppliers
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ERPProvider>();
    final curr = prov.currency;
    final list = prov.contacts.where((c) {
      if (_tab == 1 && c.contactType == 'supplier') return false;
      if (_tab == 2 && c.contactType == 'customer') return false;
      if (_search.isNotEmpty && !c.name.contains(_search)) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('العملاء والموردون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('الكل')),
                    ButtonSegment(value: 1, label: Text('عملاء')),
                    ButtonSegment(value: 2, label: Text('موردون')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'بحث بالاسم...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(
                    message: 'لا توجد جهات اتصال',
                    icon: Icons.people_outline,
                    actionLabel: 'إضافة عميل',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactForm(defaultType: 'customer'),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final bal = prov.contactBalance(c.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContactStatementScreen(contactId: c.id),
                            ),
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                (bal >= 0 ? AppColors.info : AppColors.danger)
                                    .withValues(alpha: 0.12),
                            child: Icon(
                              c.contactType == 'supplier'
                                  ? Icons.local_shipping
                                  : Icons.person,
                              color:
                                  bal >= 0 ? AppColors.info : AppColors.danger,
                            ),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            c.phone.isEmpty ? _typeLabel(c.contactType) : c.phone,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Fmt.money(bal.abs(), curr),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: bal >= 0
                                      ? AppColors.info
                                      : AppColors.danger,
                                ),
                              ),
                              Text(
                                bal >= 0 ? 'مدين' : 'دائن',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: bal >= 0
                                      ? AppColors.info
                                      : AppColors.danger,
                                ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactForm()),
        ),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  String _typeLabel(String t) {
    return switch (t) {
      'supplier' => 'مورد',
      'both' => 'عميل ومورد',
      _ => 'عميل',
    };
  }
}
