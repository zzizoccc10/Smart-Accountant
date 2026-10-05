// ============================================================================
// عناصر واجهة مشتركة — لوحة تحكم مالك النظام
// ============================================================================
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// تنسيق تاريخ ISO → نص عربي مختصر
String fmtDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.isEmpty ? '—' : iso;
  return '${d.year}/${_p(d.month)}/${_p(d.day)} ${_p(d.hour)}:${_p(d.minute)}';
}

/// تاريخ فقط
String fmtDay(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso.isEmpty ? '—' : iso;
  return '${d.year}/${_p(d.month)}/${_p(d.day)}';
}

/// كم مضى منذ تاريخ (نص عربي)
String timeAgo(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
  if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
  if (diff.inDays < 365) return 'قبل ${(diff.inDays / 30).floor()} شهر';
  return 'قبل ${(diff.inDays / 365).floor()} سنة';
}

String _p(int n) => n.toString().padLeft(2, '0');

/// شارة ملونة صغيرة
class BadgeChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const BadgeChip(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// بطاقة إحصائية
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

/// صف مفتاح/قيمة
class KvRow extends StatelessWidget {
  final String k;
  final String v;
  final IconData? icon;
  const KvRow(this.k, this.v, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 118,
            child: Text(k,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(v.isEmpty ? '—' : v,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// عنوان قسم
class SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Widget? trailing;
  const SectionTitle(this.text, this.icon, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// أيقونة النظام
IconData platformIcon(String platform) {
  switch (platform) {
    case 'android':
      return Icons.android;
    case 'ios':
      return Icons.phone_iphone;
    case 'web':
      return Icons.language;
    default:
      return Icons.devices_other;
  }
}

String platformLabel(String platform) {
  switch (platform) {
    case 'android':
      return 'أندرويد';
    case 'ios':
      return 'آيفون';
    case 'web':
      return 'ويب';
    default:
      return platform.isEmpty ? 'غير معروف' : platform;
  }
}

/// حالة فارغة
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  const EmptyState(this.icon, this.title, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ],
        ),
      ),
    );
  }
}

/// مفتاح/قيمة بشكل بطاقة صغيرة في شبكة
class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const MiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}
