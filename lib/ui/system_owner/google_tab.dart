// ============================================================================
// تبويب حسابات Google — GoogleTab
// ----------------------------------------------------------------------------
// المستخدمون الذين دخلوا عبر مصادقة Google. نفس تفاصيل المنشآت/الزوار:
// البريد + الاسم + نوع الهاتف + الدولة + آخر ظهور + عدد مرات الدخول.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../services/control_service.dart';
import '../../theme/app_theme.dart';
import 'company_detail_screen.dart';
import 'widgets.dart';

class GoogleTab extends StatefulWidget {
  const GoogleTab({super.key});

  @override
  State<GoogleTab> createState() => _GoogleTabState();
}

class _GoogleTabState extends State<GoogleTab> {
  static const int pageSize = 25;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GoogleAccount> get _filtered {
    var list = ControlService.allGoogleAccounts();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((g) {
        return g.email.toLowerCase().contains(q) ||
            g.displayName.toLowerCase().contains(q) ||
            g.country.contains(q) ||
            g.model.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final totalPages = all.isEmpty ? 1 : ((all.length - 1) ~/ pageSize) + 1;
    if (_page > totalPages) _page = totalPages;
    final items = all.skip((_page - 1) * pageSize).take(pageSize).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {
              _query = v;
              _page = 1;
            }),
            decoration: InputDecoration(
              hintText: 'ابحث بالبريد أو الاسم…',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              BadgeChip(
                '${all.length} حساب',
                AppColors.danger,
                icon: Icons.g_mobiledata,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  Icons.g_mobiledata,
                  'لا توجد حسابات Google',
                  hint: 'يُسجَّل هنا كل من دخل زر «الدخول عبر Google».',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _googleCard(items[i]),
                ),
        ),
        if (all.isNotEmpty) _pager(all.length, totalPages),
      ],
    );
  }

  Widget _googleCard(GoogleAccount g) {
    final co = g.companyId.isEmpty
        ? null
        : ControlService.companyById(g.companyId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.danger.withValues(alpha: 0.85),
              backgroundImage: g.photoUrl.isNotEmpty
                  ? NetworkImage(g.photoUrl)
                  : null,
              child: g.photoUrl.isNotEmpty
                  ? null
                  : Text(
                      (g.displayName.isNotEmpty
                              ? g.displayName
                              : g.email.isNotEmpty
                              ? g.email
                              : '?')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.displayName.isEmpty ? g.email : g.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (g.email.isNotEmpty && g.displayName.isNotEmpty)
                    Text(
                      g.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BadgeChip(
                        platformLabel(g.platform),
                        AppColors.info,
                        icon: platformIcon(g.platform),
                      ),
                      if (g.model.isNotEmpty)
                        BadgeChip(
                          g.model,
                          AppColors.purple,
                          icon: Icons.phone_android,
                        ),
                      BadgeChip(
                        g.country.isEmpty ? 'غير معروف' : g.country,
                        AppColors.teal,
                        icon: Icons.public,
                      ),
                      BadgeChip(
                        '${g.loginCount} دخول',
                        AppColors.indigo,
                        icon: Icons.login,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'أول دخول: ${fmtDay(g.firstSeenAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'آخر دخول: ${timeAgo(g.lastSeenAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (co != null)
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CompanyDetailScreen(companyId: co.id),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.business,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'المنشأة: ${co.companyName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.danger,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dlgCtx) => AlertDialog(
                    title: const Text('حذف حساب Google'),
                    content: const Text('هل تريد حذف هذا السجل؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dlgCtx, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                        ),
                        onPressed: () => Navigator.pop(dlgCtx, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ControlService.deleteGoogleAccount(g.id);
                  if (mounted) setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pager(int total, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          Text(
            'صفحة $_page من $totalPages • $total حساب',
            style: const TextStyle(fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page < totalPages
                ? () => setState(() => _page++)
                : null,
          ),
        ],
      ),
    );
  }
}
