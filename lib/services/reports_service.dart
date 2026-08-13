import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// General "Report a Problem" disputes (`reports/{id}`) — distinct from
/// [WorkerProfileActionsService.reportWorker], which targets a specific
/// worker. This is an app-wide issue report with no particular target.
class ReportsService {
  ReportsService._();
  static final ReportsService instance = ReportsService._();

  Future<void> submit({required String reporterId, required String issue, required String details, Uint8List? evidenceBytes}) async {
    final ref = FirebaseFirestore.instance.collection('reports').doc();
    String? evidenceUrl;
    if (evidenceBytes != null) {
      final storageRef = FirebaseStorage.instance.ref('reports/$reporterId/${ref.id}.jpg');
      await storageRef.putData(evidenceBytes, SettableMetadata(contentType: 'image/jpeg'));
      evidenceUrl = await storageRef.getDownloadURL();
    }
    await ref.set({
      'reporterId': reporterId,
      'reason': issue,
      'details': details,
      if (evidenceUrl != null) 'evidenceUrl': evidenceUrl,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
