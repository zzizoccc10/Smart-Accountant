// ============================================================================
// لوحة تحكم مالك النظام — SystemOwnerDashboard
// ----------------------------------------------------------------------------
// خمس واجهات:
//   1) الداشبورد الرئيسية : ملخص عام عن كل شيء + رسوم بيانية بسيطة.
//   2) المنشآت            : بحث + فلتر + ترقيم (20/صفحة) + عدّاد عمليات.
//   3) العمليات           : كل عملية تحصل في الأجهزة/المنشآت المحدّدة.
//   4) الزوار             : من دخلوا بدون حساب.
//   5) حسابات Google      : من دخلوا عبر مصادقة Google.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/control_service.dart';
import '../../services/device_service.dart';
import '../../services/stats_service.dart';
import '../../theme/app_theme.dart';
import 'companies_tab.dart';
import 'google_tab.dart';
import 'guests_tab.dart';
import 'operations_tab.dart';
import 'widgets.dart';

class SystemOwnerDashboard extends StatefulWidget {
  const SystemOwnerDashboard({super.key});

  @override
  State<SystemOwnerDashboard> createState() => _SystemOwnerDashboardState();
}

class _SystemOwnerDashboardState extends State<SystemOwnerDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _syncCloud();
  }

  Future<void> _syncCloud() async {
    if (!ControlService.isCloudAvailable) return;
    setState(() => _syncing = true);
    try {
      await ControlService.pullCompaniesFromCloud();
    } catch (_) {}
    if (mounted) setState(() => _syncing = false);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم مالك النظام'),
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _syncCloud,
            ),
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await session.signOut();
              if (context.mounted) Navigator.of(context).pop(true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'الداشبورد', icon: Icon(Icons.dashboard, size: 19)),
            Tab(text: 'المنشآت', icon: Icon(Icons.business, size: 19)),
            Tab(text: 'العمليات', icon: Icon(Icons.history, size: 19)),
            Tab(text: 'الزوار', icon: Icon(Icons.person_outline, size: 19)),
            Tab(text: 'Google', icon: Icon(Icons.g_mobiledata, size: 22)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _HomeDashboard(onRefresh: _syncCloud),
          const CompaniesTab(),
          const OperationsTab(),
          const GuestsTab(),
          const GoogleTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// التبويب 1 — الداشبورد الرئيسية
// ============================================================================
class _HomeDashboard extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const _HomeDashboard({required this.onRefresh});

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        if (mounted) setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _cloudBanner(),
          const SizedBox(height: 12),
          _summaryGrid(),
          const SizedBox(height: 18),
          _opsChart(),
          const SizedBox(height: 18),
          _topCompanies(),
          const SizedBox(height: 18),
          _recentOps(),
          const SizedBox(height: 18),
          _platformDistribution(),
          const SizedBox(height: 18),
          _topCountries(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _cloudBanner() {
    final ok = ControlService.isCloudAvailable;
    return Card(
      color: ok
          ? AppColors.success.withValues(alpha: 0.08)
          : Colors.orange.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(ok ? Icons.cloud_done : Icons.cloud_off,
            color: ok ? AppColors.success : Colors.orange),
        title: Text(
          ok ? 'متصل بـ Firebase — المزامنة مُفعّلة' : 'غير متصل — بيانات محلية',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'معرّف جهازك: ${DeviceService.deviceId} • '
          '${DeviceService.platform} • ${DeviceService.country}',
          style: const TextStyle(fontSize: 10.5),
        ),
      ),
    );
  }

  Widget _summaryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('ملخص عام', Icons.insights),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'المنشآت',
                value: '${StatsService.companiesCount}',
                icon: Icons.business,
                color: AppColors.primary,
                subtitle: '${StatsService.activeCompaniesCount} نشطة • '
                    '${StatsService.stoppedCompaniesCount} موقوفة',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'المستخدمون',
                value: '${StatsService.usersCount}',
                icon: Icons.people,
                color: AppColors.teal,
                subtitle: '${StatsService.activeUsersCount} نشط',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'العمليات',
                value: '${StatsService.operationsCount}',
                icon: Icons.sync_alt,
                color: AppColors.indigo,
                subtitle: 'اليوم: ${StatsService.operationsToday}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'الأجهزة',
                value: '${StatsService.devicesCount}',
                icon: Icons.devices,
                color: AppColors.purple,
                subtitle: '${StatsService.accountsCreatedCount} أنشأوا حساباً',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'الزوار',
                value: '${StatsService.guestsCount}',
                icon: Icons.person_outline,
                color: AppColors.warning,
                subtitle: '${StatsService.guestsConverted} تحوّلوا لحساب',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                label: 'حسابات Google',
                value: '${StatsService.googleCount}',
                icon: Icons.g_mobiledata,
                color: AppColors.danger,
                subtitle: 'دخلوا عبر Google',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _opsChart() {
    final data = StatsService.opsByDay(days: 7);
    final maxV = data.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('العمليات خلال 7 أيام', Icons.bar_chart),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((e) {
                  final h = maxV == 0 ? 0.0 : (e.value / maxV) * 90;
                  final day = e.key.split('-').last;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e.value}',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          height: h < 3 ? 3 : h,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.75),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(day,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topCompanies() {
    final list = StatsService.topCompaniesByOps(limit: 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('أكثر المنشآت نشاطاً', Icons.leaderboard),
        if (list.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('لا توجد منشآت بعد', style: TextStyle(fontSize: 13)),
            ),
          )
        else
          Card(
            child: Column(
              children: list.map((c) {
                final ops = StatsService.opsOfCompany(c.id);
                final us = StatsService.usersOfCompany(c.id);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        c.isActive ? AppColors.primary : Colors.grey,
                    child: Text(c.initials,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ),
                  title: Text(c.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('$us مستخدم • $ops عملية',
                      style: const TextStyle(fontSize: 11)),
                  trailing: BadgeChip('$ops', AppColors.indigo,
                      icon: Icons.sync_alt),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _recentOps() {
    final ops = StatsService.recentOperations(limit: 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('أحدث العمليات', Icons.history),
        if (ops.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('لا توجد عمليات مسجّلة',
                  style: TextStyle(fontSize: 13)),
            ),
          )
        else
          Card(
            child: Column(
              children: ops.map((o) {
                final co = ControlService.companyById(o.companyId);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.indigo.withValues(alpha: 0.14),
                    child: const Icon(Icons.bolt,
                        size: 15, color: AppColors.indigo),
                  ),
                  title: Text(o.actionLabelAr,
                      style: const TextStyle(fontSize: 12.5)),
                  subtitle: Text(
                    '${o.userName.isEmpty ? "—" : o.userName}'
                    '${co != null ? " • ${co.companyName}" : ""}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: Text(timeAgo(o.createdAt),
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _platformDistribution() {
    final map = StatsService.devicesByPlatform;
    if (map.isEmpty) return const SizedBox.shrink();
    final total = map.values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('توزيع الأجهزة حسب النظام', Icons.phone_android),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: map.entries.map((e) {
                final ratio = total == 0 ? 0.0 : e.value / total;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(platformIcon(e.key),
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(platformLabel(e.key),
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          Text('${e.value}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topCountries() {
    final list = StatsService.topCountries(limit: 6);
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('أكثر الدول استخداماً', Icons.public),
        Card(
          child: Column(
            children: list
                .map((e) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.flag,
                          size: 18, color: AppColors.teal),
                      title: Text(e.key,
                          style: const TextStyle(fontSize: 13)),
                      trailing: BadgeChip('${e.value}', AppColors.teal),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
