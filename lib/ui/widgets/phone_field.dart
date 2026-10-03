// ============================================================================
// حقل الهاتف — مع قائمة اختيار مفتاح الدولة (اليمن افتراضي) + جلب من جهات الاتصال
// - تحميل جهات الاتصال بشكل غير حاجب مع تخزين مؤقت (سريع ولا يعلّق الواجهة)
// - يحفظ الرقم كاملاً (مفتاح الدولة + الرقم) في المتحكم الخارجي دائماً
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../../services/contacts_service.dart';
import '../../services/country_codes.dart';
import '../../theme/app_theme.dart';
import 'permission_helper.dart';
import 'package:permission_handler/permission_handler.dart';

class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool allowPickContact;
  final ValueChanged<String>? onNamePicked;
  final ValueChanged<String>? onPhoneChanged;
  final FormFieldValidator<String>? validator;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'الهاتف',
    this.allowPickContact = true,
    this.onNamePicked,
    this.onPhoneChanged,
    this.validator,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  Country _country = Countries.defaultCountry;
  final _local = TextEditingController();
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    final (dial, local) = Countries.split(widget.controller.text);
    _country = Countries.byDial(dial) ?? Countries.defaultCountry;
    _local.text = local;
    _local.addListener(_syncOut);
    // اكتب القيمة الموحّدة فوراً لضمان وجود الرقم كاملاً
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOut());
  }

  @override
  void didUpdateWidget(covariant PhoneField old) {
    super.didUpdateWidget(old);
    // إن تغيّر النص من الخارج ولم يكن مطابقاً لما نبني محلياً، أعِد المزامنة
    final (dial, local) = Countries.split(widget.controller.text);
    if (_local.text != local ||
        (_country.dial != dial && Countries.byDial(dial) != null)) {
      _country = Countries.byDial(dial) ?? _country;
      _local.text = local;
    }
  }

  @override
  void dispose() {
    _local.removeListener(_syncOut);
    _local.dispose();
    super.dispose();
  }

  /// يكتب الرقم الكامل (مفتاح + رقم) في المتحكم الخارجي
  void _syncOut() {
    final full = Countries.compose(_country.dial, _local.text);
    if (widget.controller.text != full) {
      widget.controller.text = full;
    }
    widget.onPhoneChanged?.call(full);
  }

  Future<void> _pickDial() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text('اختر الدولة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          for (final c in Countries.all)
            ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
              title: Text(c.name),
              trailing: Text(c.dial,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              selected: c.dial == _country.dial,
              onTap: () => Navigator.pop(ctx, c),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() => _country = picked);
      _syncOut();
    }
  }

  Future<void> _pickFromContacts() async {
    final ok = await ensurePermission(
      context,
      Permission.contacts,
      reason: 'لجلب رقم الهاتف واسم الجهة من دفتر هاتفك مباشرة',
    );
    if (!ok) return;

    // جهات الاتصال من الذاكرة المؤقتة (فوري) أو تحميل أولي مع مؤشر تقدّم
    List<fc.Contact> all;
    if (ContactsService.hasCache) {
      all = await ContactsService.load();
    } else {
      setState(() => _loadingContacts = true);
      try {
        all = await ContactsService.load();
      } catch (_) {
        if (mounted) setState(() => _loadingContacts = false);
        return;
      }
      if (!mounted) return;
      setState(() => _loadingContacts = false);
    }
    if (!mounted) return;

    final withPhone = ContactsService.withValidPhone(all);
    if (withPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد جهات اتصال بأرقام هاتف')),
      );
      return;
    }

    if (!mounted) return;
    final picked = await showModalBottomSheet<fc.Contact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final list = q.isEmpty
                ? withPhone
                : withPhone
                    .where((c) => c.displayName.toLowerCase().contains(q.toLowerCase()))
                    .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'بحث في جهات الاتصال...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setSt(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('لا توجد نتائج'))
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final c = list[i];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0x1A1565C0),
                                  child: Icon(Icons.person,
                                      color: AppColors.primary),
                                ),
                                title: Text(c.displayName.isEmpty
                                    ? '(بدون اسم)'
                                    : c.displayName),
                                subtitle: Text(
                                  ContactsService.bestPhone(c) ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () => Navigator.pop(ctx, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (picked == null) return;
    final raw = ContactsService.bestPhone(picked) ?? '';
    final (dial, local) = Countries.split(raw);
    setState(() {
      _country = Countries.byDial(dial) ?? Countries.defaultCountry;
      _local.text = local;
    });
    _syncOut();
    widget.onNamePicked?.call(picked.displayName);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // مفتاح الدولة
        InkWell(
          onTap: _pickDial,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(_country.dial,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // الرقم المحلي
        Expanded(
          child: TextFormField(
            controller: _local,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: const Icon(Icons.phone),
              suffixIcon: widget.allowPickContact
                  ? (_loadingContacts
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.contacts),
                          tooltip: 'من جهات الاتصال',
                          onPressed: _pickFromContacts,
                        ))
                  : null,
            ),
            onChanged: (_) => _syncOut(),
            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}
