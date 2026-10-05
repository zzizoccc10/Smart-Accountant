// ============================================================================
// تبويب الزوار — GuestsTab
// ----------------------------------------------------------------------------
// المستخدمون الذين دخلوا بدون حساب. يعرضون بنفس تفاصيل المنشآت:
// نوع الهاتف + الدولة + آخر ظهور + عدد الزيارات + هل تحوّلوا إلى حساب.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../services/control_service.dart';
import '../../theme/app_theme.dart';
import 'widgets.dart';

class GuestsTab extends StatefulWidget {
  const GuestsTab({super.key});

  @override
  State<GuestsTab> createState() => _GuestsTabState();
}

class _GuestsTabState extends State<GuestsTab> {
  static const int pageSize = 25;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlyConverted = false;
  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GuestAccount> get _filtered {
    var list = ControlService.allGuests();
    if (_onlyConverted) list = list.where((g) => g.converted).toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((g) {
        return g.deviceId.toLowerCase().contains(q) ||
            g.model.toLowerCase().contains(q) ||
            g.country.contains(q) ||
            g.platform.toLowerCase().contains(q);
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
              hintText: 'ابحث عن زائر (جهاز/دولة/نظام)…',
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
              BadgeChip('${all.length} زائر', AppColors.warning,
                  icon: Icons.person_outline),
              const Spacer(),
              FilterChip(
                label: const Text('تحوّلوا لحساب فقط',
                    style: TextStyle(fontSize: 11.5)),
                selected: _onlyConverted,
                selectedColor: AppColors.success.withValues(alpha: 0.18),
                onSelected: (v) => setState(() {
                  _onlyConverted = v;
                  _page = 1;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  Icons.person_off_outlined,
                  'لا يوجد زوار',
                  hint: 'يُسجَّل هنا كل من دخل التطبيق من زر «الدخول بدون حساب».',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _guestCard(items[i]),
                ),
        ),
        if (all.isNotEmpty) _pager(all.length, totalPages),
      ],
    );
  }

  Widget _guestCard(GuestAccount g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: g.converted
                  ? AppColors.success
                  : AppColors.warning.withValues(alpha: 0.85),
              child: Icon(platformIcon(g.platform),
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.model.isEmpty ? platformLabel(g.platform) : g.model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (g.converted)
                        const BadgeChip('تحوّل لحساب', AppColors.success,
                            icon: Icons.check_circle_outline),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BadgeChip(platformLabel(g.platform), AppColors.info,
                          icon: platformIcon(g.platform)),
                      BadgeChip(
                          g.country.isEmpty ? 'غير معروف' : g.country,
                          AppColors.teal,
                          icon: Icons.public),
                      BadgeChip('${g.visits} زيارة', AppColors.indigo,
                          icon: Icons.repeat),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text('أول ظهور: ${fmtDay(g.firstSeenAt)}',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade600)),
                  Text('آخر ظهور: ${timeAgo(g.lastSeenAt)}',
                      style: TextStyle(
                          fontSize: 10.5, color: Colors.grey.shade600)),
                  Text('المعرّف: ${g.deviceId}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
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
                    title: const Text('حذف سجل الزائر'),
                    content: const Text('هل تريد حذف هذا السجل؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dlgCtx, false),
                          child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(dlgCtx, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ControlService.deleteGuest(g.id);
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
          Text('صفحة $_page من $totalPages • $total زائر',
              style: const TextStyle(fontSize: 12)),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _page < totalPages ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }
}
