import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'models/admin_capability.dart';
import 'models/admin_session.dart';
import 'services/admin_market_scope.dart';
import 'utils/guarded_functions.dart';

class AdminTeamPermissionsScreen extends StatefulWidget {
  const AdminTeamPermissionsScreen({super.key});

  @override
  State<AdminTeamPermissionsScreen> createState() =>
      _AdminTeamPermissionsScreenState();
}

class _AdminTeamMember {
  const _AdminTeamMember({
    required this.email,
    required this.displayName,
    required this.role,
    required this.branchId,
    required this.caps,
    required this.hasExplicitCaps,
    required this.active,
  });

  final String email;
  final String displayName;
  final AdminRole role;
  final String? branchId;
  final Set<String> caps;
  final bool hasExplicitCaps;
  final bool active;

  Set<String> get effectiveCaps {
    if (role == AdminRole.owner) {
      return AdminCapability.allIds();
    }
    if (role == AdminRole.branchAdmin && !hasExplicitCaps) {
      return AdminCapability.legacyBranchAdminCaps.toSet();
    }
    return caps;
  }
}

class _AdminTeamPermissionsScreenState extends State<AdminTeamPermissionsScreen> {
  bool _busy = false;

  AdminSession get _session =>
      AdminSessionService.instance.session ?? const AdminSession(allowed: false);

  Stream<QuerySnapshot<Map<String, dynamic>>> _teamStream() {
    final col = FirebaseFirestore.instance.collection('admins');
    if (_session.isOwner) {
      return col.snapshots();
    }
    final branchId = _session.normalizedAssignedBranchId;
    if (branchId == null) {
      return col.where('branchId', isEqualTo: '__none__').snapshots();
    }
    return col.where('branchId', isEqualTo: branchId).snapshots();
  }

  List<_AdminTeamMember> _parse(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final members = snapshot.docs.map((doc) {
      final data = doc.data();
      return _AdminTeamMember(
        email: (data['email']?.toString() ?? doc.id).trim().toLowerCase(),
        displayName: (data['displayName']?.toString() ?? doc.id).trim(),
        role: AdminSession.parseRole(data['role']?.toString()),
        branchId: data['branchId']?.toString().trim(),
        caps: AdminCapability.parse(data['allowedCaps']),
        hasExplicitCaps: data.containsKey('allowedCaps'),
        active: data['active'] != false,
      );
    }).toList();

    if (_session.isBranchAdmin) {
      members.removeWhere(
        (member) =>
            member.role == AdminRole.owner ||
            member.email == _session.email,
      );
    }

    members.sort((left, right) {
      final roleCompare = left.role.index.compareTo(right.role.index);
      if (roleCompare != 0) {
        return roleCompare;
      }
      return left.displayName.compareTo(right.displayName);
    });
    return members;
  }

  Set<String> get _grantableCaps => _session.effectiveCaps;

  Future<void> _openEditor({_AdminTeamMember? member}) async {
    final result = await showModalBottomSheet<_TeamEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _TeamEditSheet(
          existing: member,
          grantableCaps: _grantableCaps,
          session: _session,
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (member == null) {
        await GuardedFunctions.call(
          'adminProvisionBranchAdmin',
          parameters: <String, dynamic>{
            'email': result.email,
            'displayName': result.displayName,
            'role': result.role == AdminRole.staffAdmin
                ? 'staff_admin'
                : 'branch_admin',
            'branchId': result.branchId,
            'allowedCaps': result.caps,
          },
        );
      } else {
        await GuardedFunctions.call(
          'adminGrantCaps',
          parameters: <String, dynamic>{
            'email': result.email,
            'allowedCaps': result.caps,
            'branchId': result.branchId,
            'role': result.role == AdminRole.staffAdmin
                ? 'staff_admin'
                : 'branch_admin',
            'displayName': result.displayName,
            'active': result.active,
          },
        );
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกสิทธิ์ ${result.email} แล้ว')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.canDelegate) {
      return const Scaffold(
        body: Center(child: Text('ไม่มีสิทธิ์มอบงาน')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _session.isOwner ? 'สิทธิ์ผู้จัดการสาขา / แอดมิน' : 'สิทธิ์แอดมินสาขา',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(_session.isOwner ? 'เพิ่มผู้จัดการ/แอดมิน' : 'เพิ่มแอดมิน'),
      ),
      body: Column(
        children: <Widget>[
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teamStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = _parse(snapshot.data!);
                if (members.isEmpty) {
                  return const Center(child: Text('ยังไม่มีคนในทีมนี้'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final capCount = member.effectiveCaps.length;
                    return ListTile(
                      tileColor: const Color(0xFFFFF7ED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(member.displayName),
                      subtitle: Text(
                        '${member.email}\n${AdminSession.roleLabel(member.role)}'
                        '${member.branchId != null ? ' · ${member.branchId}' : ''}'
                        ' · $capCount หัวข้อ'
                        '${member.active ? '' : ' · ปิดใช้'}',
                      ),
                      isThreeLine: true,
                      enabled: member.role != AdminRole.owner,
                      onTap: member.role == AdminRole.owner
                          ? null
                          : () => _openEditor(member: member),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamEditResult {
  const _TeamEditResult({
    required this.email,
    required this.displayName,
    required this.role,
    required this.branchId,
    required this.caps,
    required this.active,
  });

  final String email;
  final String displayName;
  final AdminRole role;
  final String branchId;
  final List<String> caps;
  final bool active;
}

class _TeamEditSheet extends StatefulWidget {
  const _TeamEditSheet({
    required this.existing,
    required this.grantableCaps,
    required this.session,
  });

  final _AdminTeamMember? existing;
  final Set<String> grantableCaps;
  final AdminSession session;

  @override
  State<_TeamEditSheet> createState() => _TeamEditSheetState();
}

class _TeamEditSheetState extends State<_TeamEditSheet> {
  late final TextEditingController _email;
  late final TextEditingController _name;
  late AdminRole _role;
  late String _branchId;
  late Set<String> _caps;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _email = TextEditingController(text: existing?.email ?? '');
    _name = TextEditingController(text: existing?.displayName ?? '');
    _role = existing?.role ??
        (widget.session.isOwner ? AdminRole.branchAdmin : AdminRole.staffAdmin);
    _branchId = existing?.branchId ??
        widget.session.normalizedAssignedBranchId ??
        AdminMarketScope.instance.defaultMarketId;
    _caps = Set<String>.from(existing?.effectiveCaps ?? widget.grantableCaps);
    _caps.removeWhere((id) => !widget.grantableCaps.contains(id));
    _active = existing?.active ?? true;
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branches = AdminMarketScope.instance.activeMarkets;
    final topics = AdminCapability.topics
        .where((topic) => widget.grantableCaps.contains(topic.id))
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.existing == null ? 'เพิ่มคนในทีม' : 'แก้สิทธิ์',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              enabled: widget.existing == null,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'อีเมล'),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'ชื่อแสดง'),
            ),
            if (widget.session.isOwner)
              DropdownButtonFormField<AdminRole>(
                value: _role == AdminRole.staffAdmin
                    ? AdminRole.staffAdmin
                    : AdminRole.branchAdmin,
                decoration: const InputDecoration(labelText: 'ชั้น'),
                items: const <DropdownMenuItem<AdminRole>>[
                  DropdownMenuItem(
                    value: AdminRole.branchAdmin,
                    child: Text('ผู้จัดการสาขา'),
                  ),
                  DropdownMenuItem(
                    value: AdminRole.staffAdmin,
                    child: Text('แอดมินสาขา'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              )
            else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('ชั้น: แอดมินสาขา'),
              ),
            if (widget.session.isOwner)
              DropdownButtonFormField<String>(
                value: branches.any((branch) => branch.id == _branchId)
                    ? _branchId
                    : (branches.isEmpty ? null : branches.first.id),
                decoration: const InputDecoration(labelText: 'สาขา'),
                items: branches
                    .map(
                      (branch) => DropdownMenuItem<String>(
                        value: branch.id,
                        child: Text(branch.displayLabel),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _branchId = value);
                  }
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปิดใช้งาน'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 8),
            Text(
              'หัวข้องานที่ทำได้',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...topics.map((topic) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _caps.contains(topic.id),
                title: Text(topic.label),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _caps.add(topic.id);
                    } else {
                      _caps.remove(topic.id);
                    }
                  });
                },
              );
            }),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final email = _email.text.trim().toLowerCase();
                if (!email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ต้องมีอีเมลที่ถูกต้อง')),
                  );
                  return;
                }
                if (_branchId.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ต้องเลือกสาขา')),
                  );
                  return;
                }
                Navigator.of(context).pop(
                  _TeamEditResult(
                    email: email,
                    displayName: _name.text.trim().isEmpty
                        ? email
                        : _name.text.trim(),
                    role: widget.session.isOwner ? _role : AdminRole.staffAdmin,
                    branchId: _branchId,
                    caps: _caps.toList()..sort(),
                    active: _active,
                  ),
                );
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}
