import 'admin_capability.dart';
import 'admin_market.dart';

enum AdminRole {
  owner,
  branchAdmin,
  staffAdmin,
}

/// Resolved admin privileges from `admins/{email}` after login.
class AdminSession {
  const AdminSession({
    required this.allowed,
    this.reason,
    this.email,
    this.role = AdminRole.owner,
    this.assignedBranchId,
    this.allowedCaps = const <String>{},
    this.hasExplicitCaps = false,
  });

  final bool allowed;
  final String? reason;
  final String? email;
  final AdminRole role;
  final String? assignedBranchId;
  final Set<String> allowedCaps;
  final bool hasExplicitCaps;

  bool get isOwner => role == AdminRole.owner;

  /// Legacy alias — same as [isOwner].
  bool get isSuperAdmin => isOwner;

  bool get isBranchAdmin => role == AdminRole.branchAdmin;
  bool get isStaffAdmin => role == AdminRole.staffAdmin;
  bool get isBranchScoped => isBranchAdmin || isStaffAdmin;
  bool get canSelectBranch => isOwner;
  bool get canDelegate => isOwner || isBranchAdmin;

  String? get normalizedAssignedBranchId {
    final value = assignedBranchId?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return AdminMarket.normalizeBranchId(value);
  }

  Set<String> get effectiveCaps {
    if (isOwner) {
      return AdminCapability.allIds();
    }
    if (isBranchAdmin && !hasExplicitCaps) {
      return AdminCapability.legacyBranchAdminCaps.toSet();
    }
    return allowedCaps;
  }

  bool hasCap(String capability) {
    if (!allowed) {
      return false;
    }
    if (isOwner) {
      return true;
    }
    return effectiveCaps.contains(capability);
  }

  static AdminSession denied(String reason, {String? email}) {
    return AdminSession(allowed: false, reason: reason, email: email);
  }

  static AdminRole parseRole(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == 'branch_admin' || value == 'branchadmin' || value == 'branch') {
      return AdminRole.branchAdmin;
    }
    if (value == 'staff_admin' ||
        value == 'staffadmin' ||
        value == 'staff' ||
        value == 'admin') {
      return AdminRole.staffAdmin;
    }
    return AdminRole.owner;
  }

  static String roleLabel(AdminRole role) {
    return switch (role) {
      AdminRole.owner => 'เจ้าของระบบ',
      AdminRole.branchAdmin => 'ผู้จัดการสาขา',
      AdminRole.staffAdmin => 'แอดมินสาขา',
    };
  }
}

/// Holds the active session for the logged-in admin (van4 only).
class AdminSessionService {
  AdminSessionService._();

  static final AdminSessionService instance = AdminSessionService._();

  AdminSession? _session;

  AdminSession? get session => _session;

  bool get isOwner => _session?.isOwner ?? false;

  bool get isSuperAdmin => isOwner;

  bool get isBranchAdmin => _session?.isBranchAdmin ?? false;

  bool get isStaffAdmin => _session?.isStaffAdmin ?? false;

  bool get isBranchScoped => _session?.isBranchScoped ?? false;

  bool get canDelegate => _session?.canDelegate ?? false;

  String? get assignedBranchId => _session?.normalizedAssignedBranchId;

  bool hasCap(String capability) => _session?.hasCap(capability) ?? false;

  void setSession(AdminSession session) {
    _session = session;
  }

  void clear() {
    _session = null;
  }
}
