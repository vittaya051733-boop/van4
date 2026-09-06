import 'package:flutter/material.dart';

import '../models/admin_capability.dart';
import '../models/admin_session.dart';
import '../models/admin_tax_config.dart';
import '../services/admin_tax_service.dart';
import 'admin_tax_settings_screen.dart';
import 'admin_vat_period_screen.dart';
import 'admin_income_tax_screen.dart';
import 'admin_actor_statement_screen.dart';

class TaxCapabilityGate extends StatelessWidget {
  const TaxCapabilityGate({super.key, required this.child});

  final Widget child;

  static bool get hasAccess {
    final session = AdminSessionService.instance;
    return session.hasCap(AdminCapability.taxCompliance) ||
        session.hasCap(AdminCapability.financeRoi);
  }

  @override
  Widget build(BuildContext context) {
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    return child;
  }
}

class AdminTaxHubScreen extends StatefulWidget {
  const AdminTaxHubScreen({super.key});

  @override
  State<AdminTaxHubScreen> createState() => _AdminTaxHubScreenState();
}

class _AdminTaxHubScreenState extends State<AdminTaxHubScreen> {
  AdminTaxConfig _config = const AdminTaxConfig();
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = await AdminTaxService.fetchTaxConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriod =
        AdminTaxService.periodIdFromDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์ภาษีแพลตฟอร์ม'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'งวดปัจจุบัน: $currentPeriod',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _config.vatRegistered
                              ? 'จด VAT · อัตรา ${(_config.defaultVatRate * 100).toStringAsFixed(0)}% · ${_config.pricesIncludeVat ? 'ราคารวม VAT' : 'ราคาแยก VAT'}'
                              : 'ยังไม่จด VAT — บันทึกรายได้/รายจ่ายเพื่อส่งออก CSV',
                        ),
                        if (_config.taxId.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text('เลขผู้เสียภาษี: ${_config.taxId}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NavTile(
                  icon: Icons.settings_outlined,
                  title: 'ตั้งค่าภาษี',
                  subtitle: 'นิติบุคคล · VAT · ฐานราคา',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminTaxSettingsScreen(),
                      ),
                    );
                    await _load();
                  },
                ),
                _NavTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'งวด VAT รายเดือน',
                  subtitle: 'สรุปภาษีขาย/ซื้อ · ปิดงวด · export CSV',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminVatPeriodScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.summarize_outlined,
                  title: 'ภาษีเงินได้ (รายไตรมาส)',
                  subtitle: 'P&L ประมาณการ · export ให้บัญชี',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminIncomeTaxScreen(),
                    ),
                  ),
                ),
                _NavTile(
                  icon: Icons.mail_lock_outlined,
                  title: 'ใบแจ้งยอดรายเดือน',
                  subtitle: 'PDF มีรหัสผ่านจากเลขบัตร · ส่งอีเมลวันที่ 1',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdminActorStatementScreen(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE65100)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
