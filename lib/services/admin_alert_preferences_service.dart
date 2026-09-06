import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_alert_item.dart';
import '../models/admin_alert_topic.dart';

/// Persists which alert topics the admin wants to focus on (sound, badge, emphasis).
/// Stored on `admin_presence/{uid}.alertFocusTopics` — no native plugin required.
class AdminAlertPreferencesService extends ChangeNotifier {
  AdminAlertPreferencesService._();

  static final AdminAlertPreferencesService instance =
      AdminAlertPreferencesService._();

  static const String _fieldKey = 'alertFocusTopics';

  Set<AdminAlertType> _focusedTypes =
      Set<AdminAlertType>.from(AdminAlertTopic.allTypes);
  bool _loaded = false;
  String? _loadedForUid;

  Set<AdminAlertType> get focusedTypes =>
      Set<AdminAlertType>.unmodifiable(_focusedTypes);

  bool get isLoaded => _loaded;

  bool isFocused(AdminAlertType type) => _focusedTypes.contains(type);

  bool get isAllFocused =>
      _focusedTypes.length == AdminAlertTopic.allTypes.length;

  Future<void> ensureLoaded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_loaded && _loadedForUid == uid) {
      return;
    }

    _focusedTypes = Set<AdminAlertType>.from(AdminAlertTopic.allTypes);
    _loaded = true;
    _loadedForUid = uid;

    if (uid == null || uid.isEmpty) {
      notifyListeners();
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_presence')
          .doc(uid)
          .get();
      final stored = snapshot.data()?[_fieldKey];
      if (stored is List) {
        final parsed = stored
            .whereType<String>()
            .map((name) {
              try {
                return AdminAlertType.values.byName(name);
              } catch (_) {
                return null;
              }
            })
            .whereType<AdminAlertType>()
            .toSet();
        if (parsed.isNotEmpty) {
          _focusedTypes = parsed;
        }
      }
    } catch (error, stack) {
      debugPrint('AdminAlertPreferences load failed: $error\n$stack');
    }

    notifyListeners();
  }

  Future<void> toggle(AdminAlertType type) async {
    await ensureLoaded();
    if (_focusedTypes.contains(type)) {
      if (_focusedTypes.length <= 1) {
        return;
      }
      _focusedTypes = Set<AdminAlertType>.from(_focusedTypes)..remove(type);
    } else {
      _focusedTypes = Set<AdminAlertType>.from(_focusedTypes)..add(type);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setAllFocused() async {
    await ensureLoaded();
    _focusedTypes = Set<AdminAlertType>.from(AdminAlertTopic.allTypes);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('admin_presence').doc(uid).set(
        <String, dynamic>{
          _fieldKey: _focusedTypes.map((type) => type.name).toList(),
        },
        SetOptions(merge: true),
      );
    } catch (error, stack) {
      debugPrint('AdminAlertPreferences persist failed: $error\n$stack');
    }
  }
}
