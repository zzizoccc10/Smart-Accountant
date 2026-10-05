// ============================================================================
// تبويب المنشآت — CompaniesTab
// ----------------------------------------------------------------------------
// • بحث بالاسم/المستخدم/البريد/الهاتف.
// • فلتر: الأحدث | الأكثر عمليات | الأكثر مستخدمين | آخر فترة (7/30/90 يوم).
// • ترقيم صفحات: 20 منشأة/صفحة.
// • عدّاد عمليات + عدّاد مستخدمين لكل منشأة.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../services/control_service.dart';
import '../../services/stats_service.dart';
import '../../theme/app_theme.dart';
import 'company_detail_screen.dart';
import 'widgets.dart';

class CompaniesTab extends StatefulWidget {
  const CompaniesTab({super.key});

  @override
  State<CompaniesTab> createState() => _CompaniesTabState();
}

class _CompaniesTabState extends State<CompaniesTab> {
  static const int pageSize = 20;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String _sort = 'newest';
  int _withinDays = 0;
  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CompanyAccount> get _filtered => ControlService.filterAndSort(
    query: _query,
    sort: _sort,
    withinDays: _withinDays,
    opsCount: StatsService.opsOfCompany,
    usersCount: StatsService.usersOfCompany,
  );

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final totalPages = all.isEmpty ? 1 : ((all.length - 1) ~/ pageSize) + 1;
    if (_page > totalPages) _page = totalPages;
    final start = (_page - 1) * pageSize;
    final pageItems = all.skip(start).take(pageSize).toList(growable: false);

    return Column(
      children: [
        _searchBar(),
        _filterBar(all.length),
        const Divider(height: 1),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  Icons.business_outlined,
                  'لا توجد منشآت مطابقة',
                  hint:
                      'جرّب تغيير البحث أو الفلتر. تظهر المنشآت هنا فور '
                      'إنشاء أي مستخدم حساباً من شاشة الدخول.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  itemCount: pageItems.length,
                  itemBuilder: (context, i) => _companyCard(pageItems[i]),
                ),
        ),
        if (all.isNotEmpty) _pager(all.length, totalPages),
      ],
    );
  }

  // --------------------------------------------------------------------------
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onChanged: (v) => setState(() {
          _query = v;
          _page = 1;
        }),
        decoration: InputDecoration(
          hintText: 'ابحث عن منشأة بالاسم أو اسم المستخدم أو البريد…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _query = '';
                      _page = 1;
                    });
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Widget _filterBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'الفلتر',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              BadgeChip(
                '$count منشأة',
                AppColors.primary,
                icon: Icons.business,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('الأحدث', 'newest'),
                _chip('الأكثر عمليات', 'mostOps'),
                _chip('الأكثر مستخدمين', 'mostUsers'),
                _chip('الأقدم', 'oldest'),
                const SizedBox(width: 4),
                Container(width: 1, height: 22, color: Colors.grey.shade300),
                const SizedBox(width: 8),
                _periodChip('آخر 7 أيام', 7),
                _periodChip('آخر 30 يوم', 30),
                _periodChip('آخر 90 يوم', 90),
                if (_withinDays > 0)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _withinDays = 0;
                      _page = 1;
                    }),
                    icon: const Icon(Icons.clear, size: 15),
                    label: const Text(
                      'إزالة الفترة',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final on = _sort == value;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: on,
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          color: on ? AppColors.primary : Colors.grey.shade700,
          fontWeight: on ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() {
          _sort = value;
          _page = 1;
        }),
      ),
    );
  }

  Widget _periodChip(String label, int days) {
    final on = _withinDays == days;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: on,
        selectedColor: AppColors.teal.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          color: on ? AppColors.teal : Colors.grey.shade700,
          fontWeight: on ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => setState(() {
          _withinDays = on ? 0 : days;
          _page = 1;
        }),
      ),
    );
  }

  // --------------------------------------------------------------------------
  Widget _companyCard(CompanyAccount c) {
    final ops = StatsService.opsOfCompany(c.id);
    final users = StatsService.usersOfCompany(c.id);
    final devices = StatsService.devicesOfCompany(c.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyDetailScreen(companyId: c.id),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: c.isActive
                    ? AppColors.primary
                    : Colors.grey.shade400,
                child: Text(
                  c.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                            c.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!c.isActive)
                          const BadgeChip(
                            'موقوفة',
                            AppColors.danger,
                            icon: Icons.pause_circle_outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${c.username}'
                      '${c.ownerName.isNotEmpty ? " • ${c.ownerName}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        BadgeChip(
                          '$ops عملية',
                          AppColors.indigo,
                          icon: Icons.sync_alt,
                        ),
                        BadgeChip(
                          '$users مستخدم',
                          AppColors.teal,
                          icon: Icons.people_outline,
                        ),
                        BadgeChip(
                          '$devices جهاز',
                          AppColors.purple,
                          icon: Icons.devices,
                        ),
                        BadgeChip(
                          c.plan.labelAr,
                          AppColors.info,
                          icon: Icons.workspace_premium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            c.lastLoginAt.isEmpty
                                ? 'آخر دخول: لم يدخل بعد'
                                : 'آخر دخول: ${timeAgo(c.lastLoginAt)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Switch(
                          value: c.isActive,
                          activeThumbColor: AppColors.success,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) async {
                            await ControlService.setCompanyActive(c.id, v);
                            if (mounted) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    v
                                        ? 'تم تفعيل «${c.companyName}»'
                                        : 'تم إيقاف «${c.companyName}»',
                                  ),
                                  backgroundColor: v
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
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
            tooltip: 'السابق',
            icon: const Icon(Icons.chevron_right),
            onPressed: _page > 1 ? () => setState(() => _page--) : null,
          ),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _pageNumbers(totalPages).map((p) {
                  if (p == -1) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('…'),
                    );
                  }
                  final on = p == _page;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _page = p),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: on ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'التالي',
            icon: const Icon(Icons.chevron_left),
            onPressed: _page < totalPages
                ? () => setState(() => _page++)
                : null,
          ),
          Text(
            '$total',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// أرقام الصفحات مع اختصار (1 … 4 5 6 … 20)
  List<int> _pageNumbers(int total) {
    if (total <= 7) return List.generate(total, (i) => i + 1);
    final set = <int>{1, total, _page};
    for (var i = 1; i <= 2; i++) {
      if (_page - i >= 1) set.add(_page - i);
      if (_page + i <= total) set.add(_page + i);
    }
    final sorted = set.toList()..sort();
    final out = <int>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.add(-1);
      out.add(sorted[i]);
    }
    return out;
  }
}
