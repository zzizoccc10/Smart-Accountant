// ============================================================================
// تبويب العمليات — OperationsTab
// ----------------------------------------------------------------------------
// كل عملية تحصل في الحسابات/المنشآت. بحث + فلتر (حسب المنشأة) + ترقيم.
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/control_models.dart';
import '../../services/control_service.dart';
import '../../services/operation_service.dart';
import '../../theme/app_theme.dart';
import 'company_detail_screen.dart';
import 'widgets.dart';

class OperationsTab extends StatefulWidget {
  const OperationsTab({super.key});

  @override
  State<OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<OperationsTab> {
  static const int pageSize = 30;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _companyFilter = ''; // '' = الكل
  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<OperationLog> get _filtered {
    var list = OperationService.all();
    if (_companyFilter.isNotEmpty) {
      list = list.where((o) => o.companyId == _companyFilter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final co = ControlService.companyById(o.companyId);
        return o.action.toLowerCase().contains(q) ||
            o.actionLabelAr.contains(q) ||
            o.userName.toLowerCase().contains(q) ||
            o.details.toLowerCase().contains(q) ||
            (co?.companyName.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final all = _filtered;
    final totalPages = all.isEmpty ? 1 : ((all.length - 1) ~/ pageSize) + 1;
    if (_page > totalPages) _page = totalPages;
    final pageItems = all.skip((_page - 1) * pageSize).take(pageSize).toList();
    final companies = ControlService.allCompanies();

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
              hintText: 'ابحث في العمليات…',
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
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text('كل المنشآت (${all.length})',
                      style: const TextStyle(fontSize: 12)),
                  selected: _companyFilter.isEmpty,
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() {
                    _companyFilter = '';
                    _page = 1;
                  }),
                ),
              ),
              ...companies.map((c) {
                final on = _companyFilter == c.id;
                final count = OperationService.countOfCompany(c.id);
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('${c.companyName} ($count)',
                        style: const TextStyle(fontSize: 12)),
                    selected: on,
                    selectedColor: AppColors.teal.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() {
                      _companyFilter = on ? '' : c.id;
                      _page = 1;
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: all.isEmpty
              ? const EmptyState(
                  Icons.history,
                  'لا توجد عمليات',
                  hint: 'تُسجَّل العمليات تلقائياً عند إنشاء الفواتير والقيود '
                      'والدخول والخروج وغيرها.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pageItems.length,
                  itemBuilder: (context, i) => _opTile(pageItems[i]),
                ),
        ),
        if (all.isNotEmpty) _pager(all.length, totalPages),
      ],
    );
  }

  Widget _opTile(OperationLog o) {
    final co = ControlService.companyById(o.companyId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.indigo.withValues(alpha: 0.14),
          child: const Icon(Icons.bolt, size: 17, color: AppColors.indigo),
        ),
        title: Text(o.actionLabelAr,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${o.userName.isEmpty ? "مستخدم غير معروف" : o.userName}'
              '${co != null ? " • ${co.companyName}" : ""}',
              style: const TextStyle(fontSize: 11),
            ),
            if (o.details.isNotEmpty)
              Text(o.details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
        isThreeLine: o.details.isNotEmpty,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(timeAgo(o.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(fmtDate(o.createdAt),
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
        onTap: co == null
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompanyDetailScreen(companyId: co.id),
                  ),
                );
                if (mounted) setState(() {});
              },
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
          Text('صفحة $_page من $totalPages • $total عملية',
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
