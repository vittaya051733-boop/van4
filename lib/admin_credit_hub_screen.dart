import 'package:flutter/material.dart';

import 'admin_credit_actor_screen.dart';
import 'admin_repository.dart';
import 'services/admin_credit_service.dart';

class AdminCreditHubScreen extends StatefulWidget {
  const AdminCreditHubScreen({super.key});

  @override
  State<AdminCreditHubScreen> createState() => _AdminCreditHubScreenState();
}

class _AdminCreditHubScreenState extends State<AdminCreditHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  AdminCreditOverview? _overview;
  bool _loadingOverview = true;
  String? _overviewError;
  String _merchantQuery = '';
  String _riderQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loadingOverview = true;
      _overviewError = null;
    });
    try {
      final overview = await AdminCreditService.fetchOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _loadingOverview = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _overviewError = AdminCreditService.errorMessage(error);
        _loadingOverview = false;
      });
    }
  }

  void _openMerchant(AdminMerchantWalletRow row) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminCreditActorScreen(
          uid: row.uid,
          actorType: 'merchant',
          initialDisplayName: row.displayName,
        ),
      ),
    );
  }

  void _openRider(AdminRiderRecord rider) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminCreditActorScreen(
          uid: rider.id,
          actorType: 'rider',
          initialDisplayName: rider.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('เครดิตระบบ'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFFFE0B2),
          tabs: const <Widget>[
            Tab(text: 'ภาพรวม'),
            Tab(text: 'van1 ร้าน'),
            Tab(text: 'van3 ไรเดอร์'),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _loadOverview,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _OverviewTab(
            loading: _loadingOverview,
            error: _overviewError,
            overview: _overview,
            onRetry: _loadOverview,
          ),
          _MerchantListTab(
            query: _merchantQuery,
            onQueryChanged: (value) => setState(() => _merchantQuery = value),
            onTapMerchant: _openMerchant,
          ),
          _RiderListTab(
            query: _riderQuery,
            onQueryChanged: (value) => setState(() => _riderQuery = value),
            onTapRider: _openRider,
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.loading,
    required this.error,
    required this.overview,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final AdminCreditOverview? overview;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }
    final data = overview;
    if (data == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _SummaryCard(
          title: 'van1 ร้านค้า (ledger + merchant_wallets)',
          lines: <String>[
            'ร้านในระบบ: ${data.merchantWalletCount}',
            'เครดิต ledger รวม: ฿${_money(data.merchantCreditTotal)}',
            'ถอนได้ (Omise): ฿${_money(data.merchantWithdrawableTotal)}',
            'ล็อก: ฿${_money(data.merchantLockedTotal)}',
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'van3 ไรเดอร์ (ledger credits)',
          lines: <String>[
            'ไรเดอร์: ${data.riderCount}',
            'เครดิต ledger รวม: ฿${_money(data.riderCreditTotal)}',
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'รอปล่อยเครดิต (orders)',
          lines: <String>[
            'ร้าน scheduled: ${data.shopScheduledCount} · held: ${data.shopHeldCount}',
            'ไรเดอร์ scheduled: ${data.riderScheduledCount} · held: ${data.riderHeldCount}',
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'หมายเหตุ: ปรับยอดได้เฉพาะ ledger credits — รายได้ Omise ของร้านและ prepaid ไรเดอร์อยู่ใน settlement แยก',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  static String _money(double value) => value.toStringAsFixed(0);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantListTab extends StatelessWidget {
  const _MerchantListTab({
    required this.query,
    required this.onQueryChanged,
    required this.onTapMerchant,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AdminMerchantWalletRow> onTapMerchant;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ค้นหา UID ร้าน',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminMerchantWalletRow>>(
            stream: AdminCreditService.streamMerchantWallets(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = query.trim().toLowerCase();
              final rows = snapshot.data!
                  .where(
                    (row) =>
                        q.isEmpty ||
                        row.uid.toLowerCase().contains(q) ||
                        (row.displayName?.toLowerCase().contains(q) ?? false),
                  )
                  .toList(growable: false);
              if (rows.isEmpty) {
                return const Center(child: Text('ไม่พบร้าน'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      row.displayName ?? row.uid,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'ledger ฿${row.totalCredit.toStringAsFixed(0)}'
                      ' · ถอนได้ ฿${row.withdrawableCredit.toStringAsFixed(0)}'
                      ' · ล็อก ฿${row.lockedCredit.toStringAsFixed(0)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onTapMerchant(row),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RiderListTab extends StatelessWidget {
  const _RiderListTab({
    required this.query,
    required this.onQueryChanged,
    required this.onTapRider,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AdminRiderRecord> onTapRider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ค้นหาชื่อหรือ UID ไรเดอร์',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminRiderRecord>>(
            stream: AdminRepository.streamRiders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = query.trim().toLowerCase();
              final riders = snapshot.data!
                  .where(
                    (rider) =>
                        q.isEmpty ||
                        rider.id.toLowerCase().contains(q) ||
                        rider.displayName.toLowerCase().contains(q),
                  )
                  .toList(growable: false);
              if (riders.isEmpty) {
                return const Center(child: Text('ไม่พบไรเดอร์'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: riders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rider = riders[index];
                  return ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE0B2),
                      child: Text(
                        rider.displayName.isNotEmpty
                            ? rider.displayName[0]
                            : '?',
                      ),
                    ),
                    title: Text(rider.displayName),
                    subtitle: Text(
                      '${rider.id.substring(0, 8)}… · ${rider.onlineReady ? "พร้อมรับงาน" : "ออฟไลน์"}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onTapRider(rider),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
