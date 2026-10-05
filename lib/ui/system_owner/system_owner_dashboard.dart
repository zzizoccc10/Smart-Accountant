// ============================================================================
// لوحة تحكم مالك النظام — SystemOwnerDashboard
// ----------------------------------------------------------------------------
// مركز التحকّم الشامل:
//   • نظرة عامة: إحصائيات المنشآت/المستخدمين/الأجهزة.
//   • المنشآت: عرض، تفعيل/إيقاف، منح الصلاحيات، إعادة تعيين كلمة المرور، حذف.
//   • المستخدمون: كل من أنشأ حساباً (من كل المنشآت).
//   • الأجهزة: كل من حمّل التطبيق (تنزيلات + آخر ظهور + هل أنشأ حساباً).
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/control_models.dart';
import '../../models/user_models.dart';
import '../../providers/session_provider.dart';
import '../../services/control_service.dart';
import '../../services/device_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'company_detail_screen.dart';

class SystemOwnerDashboard extends StatefulWidget {
  const SystemOwnerDashboard({super.key});

  @override
  State<SystemOwnerDashboard> createState() => _SystemOwnerDashboardState();
}

class _SystemOwnerDashboardState extends State<SystemOwnerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    // زامن من السحابة عند الفتح (لو متاحة)
    if (ControlService.isCloudAvailable) {
      ControlService.pullCompaniesFromCloud().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final companies = ControlService.allCompanies();
    final devices = ControlService.allDevices();
    final users = UserService.all();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم مالك النظام'),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ControlService.pullCompaniesFromCloud();
              setState(() {});
            },
          ),
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await session.signOut();
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'نظرة عامة', icon: Icon(Icons.insights, size: 20)),
            Tab(text: 'المنشآت', icon: Icon(Icons.business, size: 20)),
            Tab(text: 'المستخدمون', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'الأجهزة', icon: Icon(Icons.devices, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overviewTab(companies, users.length, devices),
          _companiesTab(companies),
          _usersTab(users),
          _devicesTab(devices),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // نظرة عامة
  // --------------------------------------------------------------------------
  Widget _overviewTab(
      List<CompanyAccount> companies, int userCount, List<DeviceRegistry> devices) {
    final active = companies.where((c) => c.isActive).length;
    final stopped = companies.length - active;
    final createdAccounts = devices.where((d) => d.accountCreated).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'المنشآت',
                '${companies.length}',
                Icons.business,
                AppColors.primary,
                subtitle: '$active نشطة • $stopped موقوفة',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'المستخدمون',
                '$userCount',
                Icons.people,
                AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'الأجهزة',
                '${devices.length}',
                Icons.devices,
                AppColors.indigo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'أنشأوا حساباً',
                '$createdAccounts',
                Icons.how_to_reg,
                AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text('حالة الاتصال بالسحابة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: Icon(
              ControlService.isCloudAvailable ? Icons.cloud_done : Icons.cloud_off,
              color: ControlService.isCloudAvailable
                  ? AppColors.success
                  : Colors.orange,
            ),
            title: Text(ControlService.isCloudAvailable
                ? 'متصل بـ Firebase — المزامنة مُفعّلة'
                : 'غير متصل — البيانات محلية فقط'),
            subtitle: Text(
              'معرّف الجهاز الحالي: ${DeviceService.deviceId}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('أحدث المنشآت',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (companies.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('لا توجد منشآت بعد'),
              subtitle: Text('ستظهر المنشآت التي تُنشئ حسابات من التطبيق'),
            ),
          )
        else
          ...companies.take(5).map((c) => _companyTile(c)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {String? subtitle}) {
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
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // المنشآت
  // --------------------------------------------------------------------------
  Widget _companiesTab(List<CompanyAccount> companies) {
    if (companies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text('لا توجد منشآت بعد'),
              SizedBox(height: 6),
              Text(
                'عندما ينشئ مستخدم حساب منشأة من شاشة الدخول، ستظهر هنا '
                'لتتحكم بتفعيلها وصلاحياتها.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: companies.length,
      itemBuilder: (context, i) => _companyTile(companies[i]),
    );
  }

  Widget _companyTile(CompanyAccount c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.isActive ? AppColors.primary : Colors.grey,
          child: Text(c.initials, style: const TextStyle(color: Colors.white)),
        ),
        title: Text(c.companyName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${c.username} • ${c.plan.labelAr}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                _badge(c.isActive ? 'نشطة' : 'موقوفة',
                    c.isActive ? AppColors.success : AppColors.danger),
                const SizedBox(width: 6),
                _badge('${c.privileges.granted.length} صلاحية', AppColors.info),
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: c.isActive,
          activeThumbColor: AppColors.success,
          onChanged: (v) async {
            await ControlService.setCompanyActive(c.id, v);
            setState(() {});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(v
                      ? 'تم تفعيل «${c.companyName}»'
                      : 'تم إيقاف «${c.companyName}»'),
                  backgroundColor: v ? AppColors.success : AppColors.warning,
                ),
              );
            }
          },
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyDetailScreen(companyId: c.id),
            ),
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // المستخدمون
  // --------------------------------------------------------------------------
  Widget _usersTab(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(child: Text('لا يوجد مستخدمون'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        final company = ControlService.companyById(u.companyId);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: u.isActive ? AppColors.teal : Colors.grey,
              child: Text(u.initials,
                  style: const TextStyle(color: Colors.white)),
            ),
            title: Text(u.name),
            subtitle: Text(
              '${u.role.labelAr} • ${company?.companyName ?? (u.companyId.isEmpty ? "محلي/قديم" : u.companyId)}\n'
              '${u.username.isNotEmpty ? "@${u.username}" : (u.email.isNotEmpty ? u.email : "")}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: _badge(u.isActive ? 'نشط' : 'معطّل',
                u.isActive ? AppColors.success : Colors.grey),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // الأجهزة
  // --------------------------------------------------------------------------
  Widget _devicesTab(List<DeviceRegistry> devices) {
    if (devices.isEmpty) {
      return const Center(child: Text('لا توجد أجهزة مسجّلة'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: devices.length,
      itemBuilder: (context, i) {
        final d = devices[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  d.accountCreated ? AppColors.success : Colors.blueGrey,
              child: Icon(_deviceIcon(d.platform),
                  color: Colors.white, size: 20),
            ),
            title: Text('${d.platform} • ${d.model}',
                style: const TextStyle(fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المعرّف: ${d.deviceId}',
                    style: const TextStyle(fontSize: 11)),
                Text('فتحات: ${d.launchCount} • آخر ظهور: ${_fmt(d.lastSeenAt)}',
                    style: const TextStyle(fontSize: 11)),
                if (d.userName.isNotEmpty)
                  Text('مرتبط: ${d.userName}', style: const TextStyle(fontSize: 11)),
              ],
            ),
            isThreeLine: true,
            trailing: d.accountCreated
                ? _badge('أنشأ حساباً', AppColors.success)
                : _badge('حمّل فقط', Colors.blueGrey),
          ),
        );
      },
    );
  }

  IconData _deviceIcon(String platform) {
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

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(fontSize: 10, color: color)),
      );

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
