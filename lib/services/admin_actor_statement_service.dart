import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_actor_statement.dart';
import 'admin_tax_service.dart';

class AdminActorStatementService {
  AdminActorStatementService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static CollectionReference<Map<String, dynamic>> get _statementsRef =>
      _firestore.collection('actor_statements');

  static Stream<List<AdminActorStatement>> streamForPeriod(String periodId) {
    return _statementsRef
        .where('periodId', isEqualTo: periodId)
        .snapshots()
        .map(_mapDocs);
  }

  static Future<List<AdminActorStatement>> fetchForPeriod(String periodId) async {
    final snap = await _statementsRef.where('periodId', isEqualTo: periodId).get();
    return _mapDocs(snap);
  }

  static List<AdminActorStatement> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs
        .map(AdminActorStatement.fromDoc)
        .toList(growable: true);
    docs.sort((a, b) {
      final typeCmp = a.actorType.compareTo(b.actorType);
      if (typeCmp != 0) {
        return typeCmp;
      }
      return a.displayName.compareTo(b.displayName);
    });
    return docs;
  }

  static String defaultPeriodId() {
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1, 1);
    return AdminTaxService.periodIdFromDate(previous);
  }

  static Future<Map<String, dynamic>> runMonthlyBatch({
    required String periodId,
    bool sendEmail = true,
    bool force = false,
  }) async {
    final callable = _functions.httpsCallable('adminRunMonthlyActorStatements');
    final result = await callable.call(<String, dynamic>{
      'periodId': periodId,
      'sendEmail': sendEmail,
      'force': force,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<Map<String, dynamic>> generateOne({
    required String actorType,
    required String actorUid,
    required String periodId,
    bool sendEmail = true,
    bool force = false,
  }) async {
    final callable = _functions.httpsCallable('adminGenerateActorStatement');
    final result = await callable.call(<String, dynamic>{
      'actorType': actorType,
      'actorUid': actorUid,
      'periodId': periodId,
      'sendEmail': sendEmail,
      'force': force,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  static Future<void> resendEmail(String statementId) async {
    final callable = _functions.httpsCallable('adminResendActorStatementEmail');
    await callable.call(<String, dynamic>{'statementId': statementId});
  }
}
