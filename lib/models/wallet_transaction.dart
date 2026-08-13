import 'package:cloud_firestore/cloud_firestore.dart';

enum TxType { topup, earning }

enum TxStatus { pending, confirmed, rejected }

TxType txTypeFromString(String? v) => v == 'earning' ? TxType.earning : TxType.topup;

TxStatus txStatusFromString(String? v) => switch (v) {
      'confirmed' => TxStatus.confirmed,
      'rejected' => TxStatus.rejected,
      _ => TxStatus.pending,
    };

/// A `transactions/{id}` Firestore document — the ledger entry shown in
/// wallet/earnings/transaction-detail screens. `wallet_topups/{id}` is the
/// separate pending-approval record created alongside a topup transaction.
class WalletTransaction {
  final String id;
  final String userId;
  final TxType type;
  final double amount;
  final TxStatus status;
  final String? jobId;
  final String label;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.status = TxStatus.confirmed,
    this.jobId,
    this.label = '',
    this.createdAt,
  });

  factory WalletTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WalletTransaction(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      type: txTypeFromString(d['type'] as String?),
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      status: txStatusFromString(d['status'] as String?),
      jobId: d['jobId'] as String?,
      label: d['label'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
