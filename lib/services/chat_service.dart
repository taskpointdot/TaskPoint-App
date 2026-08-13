import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;
  const ChatMessage({required this.id, required this.senderId, required this.text, this.createdAt});

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Real-time messages under `jobs/{jobId}/messages` — the worker<->seeker
/// chat tied to a specific job (not a general-purpose DM system).
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  CollectionReference<Map<String, dynamic>> _messages(String jobId) =>
      FirebaseFirestore.instance.collection('jobs').doc(jobId).collection('messages');

  Stream<List<ChatMessage>> watchMessages(String jobId) {
    return _messages(jobId).orderBy('createdAt', descending: false).snapshots().map(
          (s) => s.docs.map(ChatMessage.fromDoc).toList(),
        );
  }

  Future<void> send({required String jobId, required String senderId, required String text}) {
    return _messages(jobId).add({
      'senderId': senderId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
