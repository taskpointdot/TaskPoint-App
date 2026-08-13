import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/wallet_transaction.dart';

class WalletException implements Exception {
  final String message;
  WalletException(this.message);
  @override
  String toString() => message;
}

/// Wallet balance lives on `users/{uid}.walletBalance`; every change is
/// logged to `transactions/{id}`. Top-ups are a manual EasyPaisa/JazzCash
/// transfer (see `digital_wallet_top_up_screen.dart`'s hardcoded receiving
/// account) — this app has no admin dashboard yet to confirm them, so a
/// top-up request lands in `wallet_topups` as `pending` and does NOT credit
/// the balance until someone flips its status by hand in the Firebase
/// console (documented in the top-up screen's confirmation copy).
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  final _db = FirebaseFirestore.instance;

  Stream<List<WalletTransaction>> watchTransactions(String uid) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(WalletTransaction.fromDoc).toList());
  }

  Stream<double> watchBalance(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((d) => (d.data()?['walletBalance'] as num?)?.toDouble() ?? 0);
  }

  /// Daily earning totals for the last 7 days (oldest first), for the
  /// performance-insights bar chart.
  Future<List<double>> weeklyEarningsByDay(String uid) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: 'earning')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    final totals = List<double>.filled(7, 0);
    for (final doc in snap.docs) {
      final tx = WalletTransaction.fromDoc(doc);
      if (tx.createdAt == null) continue;
      final dayIndex = DateTime(tx.createdAt!.year, tx.createdAt!.month, tx.createdAt!.day).difference(start).inDays;
      if (dayIndex >= 0 && dayIndex < 7) totals[dayIndex] += tx.amount;
    }
    return totals;
  }

  Future<double> todayEarnings(String uid) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: uid)
        .where('type', isEqualTo: 'earning')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .aggregate(sum('amount'))
        .get();
    return snap.getSum('amount')?.toDouble() ?? 0;
  }

  /// Credits a worker's wallet for a completed job (called right after a
  /// job is marked complete).
  Future<void> recordEarning({required String uid, required String jobId, required double amount, required String label}) async {
    final userRef = _db.collection('users').doc(uid);
    final txRef = _db.collection('transactions').doc();
    await _db.runTransaction((t) async {
      t.set(txRef, {
        'userId': uid,
        'type': 'earning',
        'amount': amount,
        'status': 'confirmed',
        'jobId': jobId,
        'label': label,
        'createdAt': FieldValue.serverTimestamp(),
      });
      t.update(userRef, {'walletBalance': FieldValue.increment(amount)});
    });
  }

  /// Uploads the transfer-proof screenshot and creates the pending topup +
  /// ledger records. Returns the `wallet_topups` doc id.
  Future<String> submitTopUp({required String uid, required double amount, required String method, required Uint8List proofBytes}) async {
    final id = _db.collection('wallet_topups').doc().id;
    final ref = FirebaseStorage.instance.ref('wallet_topups/$uid/$id.jpg');
    await ref.putData(proofBytes, SettableMetadata(contentType: 'image/jpeg'));
    final proofUrl = await ref.getDownloadURL();

    await _db.collection('wallet_topups').doc(id).set({
      'userId': uid,
      'amount': amount,
      'method': method,
      'proofUrl': proofUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('transactions').add({
      'userId': uid,
      'type': 'topup',
      'amount': amount,
      'status': 'pending',
      // Back-reference so the admin dashboard can settle exactly this ledger
      // row when it confirms/rejects the top-up, instead of guessing which
      // pending row of the same amount belongs to which request.
      'topupId': id,
      'label': '$method top-up (awaiting confirmation)',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }
}
