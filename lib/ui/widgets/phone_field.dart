// ============================================================================
// حقل الهاتف — مع قائمة اختيار مفتاح الدولة (اليمن افتراضي) + جلب من جهات الاتصال
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';

import '../../services/country_codes.dart';
import '../../theme/app_theme.dart';
import 'permission_helper.dart';

class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool allowPickContact;
  final ValueChanged<String>? onNamePicked;
  final FormFieldValidator<String>? validator;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'الهاتف',
    this.allowPickContact = true,
    this.onNamePicked,
    this.validator,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  Country _country = Countries.defaultCountry;
  final _local = TextEditingController();

  @override
  void initState() {
    super.initState();
    final (dial, local) = Countries.split(widget.controller.text);
    _country = Countries.byDial(dial) ?? Countries.defaultCountry;
    _local.text = local;
  }

  @override
  void dispose() {
    _local.dispose();
    super.dispose();
  }

  void _syncOut() {
    widget.controller.text = Countries.compose(_country.dial, _local.text);
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
    List<fc.Contact> contacts;
    try {
      contacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final withPhone =
        contacts.where((c) => c.phones.isNotEmpty).toList();

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
                    .where((c) => c.displayName.contains(q))
                    .toList();
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
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
                        ? const Center(child: Text('لا توجد جهات اتصال'))
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
                                  c.phones
                                      .map((p) => p.number)
                                      .whereType<String>()
                                      .join(' • '),
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
    // خذ أول رقم متاح
    final raw = picked.phones.first.number;
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
                  ? IconButton(
                      icon: const Icon(Icons.contacts),
                      tooltip: 'من جهات الاتصال',
                      onPressed: _pickFromContacts,
                    )
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
