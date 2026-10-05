// ============================================================================
// إرسال إشعار من مالك النظام — BroadcastComposeSheet
// ----------------------------------------------------------------------------
// يتيح لمالك النظام إنشاء إشعار وتحديد المستهدفين:
//   • الجميع | منشآت محدّدة | مستخدمون محدّدون.
// ثم يُرسَل فوراً (محلياً + بثّ سحابي لكل المتصلين بالإنترنت).
// ============================================================================
import 'package:flutter/material.dart';

import '../../models/user_models.dart';
import '../../services/admin_notification_service.dart';
import '../../services/control_service.dart';
import '../../services/operation_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class BroadcastComposeSheet extends StatefulWidget {
  const BroadcastComposeSheet({super.key});

  @override
  State<BroadcastComposeSheet> createState() => _BroadcastComposeSheetState();
}

class _BroadcastComposeSheetState extends State<BroadcastComposeSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  NotifyAudience _audience = NotifyAudience.all;
  int _importance = 0;
  final Set<String> _companies = {};
  final Set<String> _users = {};
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      _snack('يرجى إدخال عنوان ونص الإشعار', error: true);
      return;
    }
    if (_audience == NotifyAudience.companies && _companies.isEmpty) {
      _snack('اختر منشأة واحدة على الأقل', error: true);
      return;
    }
    if (_audience == NotifyAudience.users && _users.isEmpty) {
      _snack('اختر مستخدماً واحداً على الأقل', error: true);
      return;
    }

    setState(() => _sending = true);
    try {
      await AdminNotificationService.send(
        title: _title.text,
        body: _body.text,
        audience: _audience,
        targetCompanies: _companies.toList(),
        targetUsers: _users.toList(),
        importance: _importance,
        senderName: ControlService.systemOwner?.name ?? 'إدارة النظام',
      );
      // سجّل العملية
      await OperationService.log(
        action: 'broadcast_send',
        userName: ControlService.systemOwner?.name ?? 'إدارة النظام',
        details: '${_audience.labelAr}: ${_title.text.trim()}',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack('فشل الإرسال: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companies = ControlService.allCompanies();
    final users = UserService.all();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // المقبض
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.campaign, color: AppColors.purple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'إرسال إشعار من إدارة النظام',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإشعار',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'نص الإشعار',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // المستهدفون
                  const Text(
                    'المستهدفون',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: NotifyAudience.values.map((a) {
                      final on = _audience == a;
                      return ChoiceChip(
                        label: Text(
                          a.labelAr,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        selected: on,
                        selectedColor: AppColors.purple.withValues(alpha: 0.18),
                        onSelected: (_) => setState(() => _audience = a),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  if (_audience == NotifyAudience.companies) ...[
                    Row(
                      children: [
                        const Text(
                          'المنشآت',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_companies.length} محدّدة)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_companies.length == companies.length) {
                              _companies.clear();
                            } else {
                              _companies
                                ..clear()
                                ..addAll(companies.map((c) => c.id));
                            }
                          }),
                          child: const Text(
                            'تحديد الكل',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (companies.isEmpty)
                      const Text(
                        'لا توجد منشآت',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      ...companies.map((c) {
                        final on = _companies.contains(c.id);
                        return CheckboxListTile(
                          dense: true,
                          value: on,
                          activeColor: AppColors.purple,
                          title: Text(
                            c.companyName,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '@${c.username}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onChanged: (v) => setState(
                            () => v == true
                                ? _companies.add(c.id)
                                : _companies.remove(c.id),
                          ),
                        );
                      }),
                  ],

                  if (_audience == NotifyAudience.users) ...[
                    Row(
                      children: [
                        const Text(
                          'المستخدمون',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_users.length} محدّد)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            if (_users.length == users.length) {
                              _users.clear();
                            } else {
                              _users
                                ..clear()
                                ..addAll(users.map((u) => u.id));
                            }
                          }),
                          child: const Text(
                            'تحديد الكل',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (users.isEmpty)
                      const Text(
                        'لا يوجد مستخدمون',
                        style: TextStyle(fontSize: 12),
                      )
                    else
                      ...users.map((u) {
                        final on = _users.contains(u.id);
                        final co = ControlService.companyById(u.companyId);
                        return CheckboxListTile(
                          dense: true,
                          value: on,
                          activeColor: AppColors.purple,
                          title: Text(
                            u.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${u.role.labelAr}'
                            '${co != null ? " • ${co.companyName}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          secondary: Icon(
                            u.role == UserRole.owner
                                ? Icons.star
                                : Icons.person_outline,
                            size: 18,
                            color: AppColors.purple,
                          ),
                          onChanged: (v) => setState(
                            () => v == true
                                ? _users.add(u.id)
                                : _users.remove(u.id),
                          ),
                        );
                      }),
                  ],

                  const SizedBox(height: 18),
                  const Text(
                    'الأهمية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _impChip(0, 'عادي', AppColors.info),
                      _impChip(1, 'مهم', AppColors.warning),
                      _impChip(2, 'عاجل', AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _sending ? 'جارٍ الإرسال…' : 'إرسال الإشعار',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _impChip(int value, String label, Color color) {
    final on = _importance == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: on,
      selectedColor: color.withValues(alpha: 0.18),
      onSelected: (_) => setState(() => _importance = value),
    );
  }
}
