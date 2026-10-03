// ============================================================================
// استيراد جهات الاتصال من دفتر هاتف الجهاز إلى قائمة العملاء/الموردين
// يتطلب صلاحية قراءة جهات الاتصال — تُطلب تلقائياً عند الفتح
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/erp_provider.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/common.dart';

class ContactsImportScreen extends StatefulWidget {
  const ContactsImportScreen({super.key});

  @override
  State<ContactsImportScreen> createState() => _ContactsImportScreenState();
}

class _PhoneContact {
  final String name;
  final String phone;
  bool selected = false;
  _PhoneContact(this.name, this.phone);
}

class _ContactsImportScreenState extends State<ContactsImportScreen> {
  bool _loading = true;
  bool _denied = false;
  String _type = 'customer';
  String _q = '';
  List<_PhoneContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _denied = false;
    });

    if (kIsWeb) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    final ok = await _ensureContactsPermission();
    if (!ok) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }

    try {
      final list = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      final out = <_PhoneContact>[];
      for (final c in list) {
        final name = c.displayName.trim();
        if (name.isEmpty) continue;
        final phone = _firstPhone(c);
        if (phone.isEmpty) continue;
        out.add(_PhoneContact(name, phone));
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _contacts = out;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _denied = true;
      });
    }
  }

  String _firstPhone(fc.Contact c) {
    if (c.phones.isEmpty) return '';
    final p = c.phones.first.number;
    return p.replaceAll(RegExp(r'\s+'), '');
  }

  Future<bool> _ensureContactsPermission() async {
    final status = await PermissionService.request(Permission.contacts);
    return status.isGranted || status.isLimited;
  }

  List<_PhoneContact> get _filtered {
    if (_q.isEmpty) return _contacts;
    final q = _q.toLowerCase();
    return _contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) || c.phone.contains(q))
        .toList();
  }

  int get _selectedCount => _contacts.where((c) => c.selected).length;

  void _toggleAll(bool v) {
    for (final c in _filtered) {
      c.selected = v;
    }
    setState(() {});
  }

  Future<void> _import() async {
    final chosen = _contacts.where((c) => c.selected).toList();
    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم تختر أي جهة اتصال')),
      );
      return;
    }
    final prov = context.read<ERPProvider>();
    final existingNames =
        prov.contacts.map((e) => e.name.trim().toLowerCase()).toSet();
    var added = 0;
    for (final c in chosen) {
      if (existingNames.contains(c.name.trim().toLowerCase())) continue;
      await prov.addContact(Contact(
        id: '',
        name: c.name,
        contactType: _type,
        phone: c.phone,
      ));
      added++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم استيراد $added جهة اتصال'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد جهات الاتصال'),
        actions: [
          if (!_loading && !_denied && _contacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة التحميل',
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _denied
              ? _deniedView()
              : _listView(),
      bottomNavigationBar: (!_loading && !_denied && _contacts.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _selectedCount > 0 ? _import : null,
                  icon: const Icon(Icons.download),
                  label: Text('استيراد المحدد ($_selectedCount)'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _deniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts_outlined,
                size: 60, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('لا يمكن الوصول لجهات الاتصال',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              kIsWeb
                  ? 'هذه الميزة متاحة داخل تطبيق الأندرويد فقط.'
                  : 'يرجى منح صلاحية الوصول لجهات الاتصال من إعدادات التطبيق.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await PermissionService.request(Permission.contacts);
                _load();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('طلب الصلاحية'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => PermissionService.openSettings(),
              icon: const Icon(Icons.settings),
              label: const Text('فتح الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView() {
    final items = _filtered;
    if (_contacts.isEmpty) {
      return const EmptyState(
        message: 'لا توجد جهات اتصال في الهاتف',
        icon: Icons.contacts_outlined,
      );
    }
    final allSelected =
        items.isNotEmpty && items.every((c) => c.selected);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'بحث بالاسم أو الرقم...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'customer', label: Text('عملاء')),
                        ButtonSegment(
                            value: 'supplier', label: Text('موردون')),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) =>
                          setState(() => _type = s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _toggleAll(!allSelected),
                    icon: Icon(allSelected
                        ? Icons.deselect
                        : Icons.select_all),
                    label: Text(allSelected ? 'إلغاء' : 'الكل'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final c = items[i];
              return CheckboxListTile(
                dense: true,
                value: c.selected,
                onChanged: (v) => setState(() => c.selected = v ?? false),
                title: Text(c.name, style: const TextStyle(fontSize: 13)),
                subtitle: Text(c.phone,
                    style: const TextStyle(fontSize: 11)),
                secondary: const Icon(Icons.person_outline),
              );
            },
          ),
        ),
      ],
    );
  }
}
