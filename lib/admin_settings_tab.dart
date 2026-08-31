import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_internal_chat_hub_screen.dart';
import 'services/admin_presence_service.dart';
import 'services/admin_startup_diagnostics.dart';
import 'utils/admin_callable_errors.dart';
import 'utils/app_check_guard.dart';
import 'utils/feature_flags.dart';
import 'utils/guarded_functions.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key, required this.user});

  final User user;

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  List<AdminDiagnosticResult>? _diagnostics;
  bool _runningDiagnostics = false;
  bool _probingFunctions = false;
  List<AdminCallableProbeResult>? _callableProbes;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _runningDiagnostics = true);
    final results = await AdminStartupDiagnostics.run();
    if (mounted) {
      setState(() {
        _diagnostics = results;
        _runningDiagnostics = false;
      });
    }
  }

  Future<void> _probeWithdrawFunctions() async {
    setState(() => _probingFunctions = true);
    const names = <String>[
      'exportWithdrawBankCsv',
      'confirmManualWithdraw',
      'rejectManualWithdraw',
      'adminUpdateOrderCreditRelease',
      'adminResolveClaim',
      'getMerchantWallet',
    ];
    final probes = <AdminCallableProbeResult>[];
    for (final name in names) {
      probes.add(await GuardedFunctions.probeCallable(name));
    }
    if (mounted) {
      setState(() {
        _callableProbes = probes;
        _probingFunctions = false;
      });
    }
  }

  Future<void> _copyDebugToken() async {
    await Clipboard.setData(
      ClipboardData(text: AppCheckGuard.debugTokenHint),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คัดลอก App Check debug token แล้ว')),
      );
    }
  }

  Future<void> _syncPresence() async {
    await AdminPresenceService.instance.ensureRegistered(force: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ซิงก์ authUid / presence แล้ว')),
      );
      await _runDiagnostics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _sectionTitle(context, 'บัญชีแอดมิน'),
        _infoCard(
          children: <Widget>[
            _infoRow('อีเมล', widget.user.email ?? '-'),
            _infoRow('UID', widget.user.uid),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _syncPresence,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('ซิงก์ authUid / presence'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'App Check'),
        _infoCard(
          children: <Widget>[
            Text(
              AppCheckGuard.usesDebugProvider
                  ? 'Debug token (Android van4.com):'
                  : 'โหมด release — ใช้ Play Integrity (debug token ใช้ไม่ได้):',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              AppCheckGuard.debugTokenHint,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _copyDebugToken,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('คัดลอก token'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AdminCallableErrors.appCheckSetupHint(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'ตรวจสุขภาพระบบ'),
        _infoCard(
          children: <Widget>[
            if (_runningDiagnostics && _diagnostics == null)
              const Center(child: CircularProgressIndicator())
            else if (_diagnostics != null)
              ..._diagnostics!.map(_diagnosticTile),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _runningDiagnostics ? null : _runDiagnostics,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(_runningDiagnostics ? 'กำลังตรวจ...' : 'ตรวจสอบใหม่'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Cloud Functions (van2)'),
        _infoCard(
          children: <Widget>[
            Text(
              'ทดสอบว่า function deploy แล้ว (ไม่ทำธุรกรรมจริง)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
            ),
            const SizedBox(height: 10),
            if (_callableProbes != null)
              ..._callableProbes!.map(_callableProbeTile),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _probingFunctions ? null : _probeWithdrawFunctions,
              icon: const Icon(Icons.cloud_outlined),
              label: Text(_probingFunctions ? 'กำลังทดสอบ...' : 'ทดสอบ functions'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'ทีมแอดมิน'),
        _infoCard(
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined, color: Color(0xFFE65100)),
              title: const Text('แชท / โทรภายในทีม'),
              subtitle: const Text('ห้องทีม + DM ระหว่างแอดมิน'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminInternalChatHubScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (kDebugMode)
          Text(
            'Build: debug',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF9CA3AF),
                ),
          ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9A3412),
            ),
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticTile(AdminDiagnosticResult result) {
    final icon = switch (result.status) {
      AdminDiagnosticStatus.ok => Icons.check_circle_outline,
      AdminDiagnosticStatus.warn => Icons.warning_amber_outlined,
      AdminDiagnosticStatus.fail => Icons.error_outline,
    };
    final color = switch (result.status) {
      AdminDiagnosticStatus.ok => const Color(0xFF15803D),
      AdminDiagnosticStatus.warn => const Color(0xFFB45309),
      AdminDiagnosticStatus.fail => Colors.redAccent,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(result.label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(result.detail, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _callableProbeTile(AdminCallableProbeResult probe) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        probe.reachable ? Icons.check_circle_outline : Icons.cloud_off_outlined,
        color: probe.reachable ? const Color(0xFF15803D) : Colors.redAccent,
        size: 20,
      ),
      title: Text(probe.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(probe.detail, style: const TextStyle(fontSize: 12)),
    );
  }
}
