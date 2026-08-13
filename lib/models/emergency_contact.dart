import 'package:cloud_firestore/cloud_firestore.dart';

/// A `users/{uid}/emergencyContacts/{id}` Firestore document.
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({required this.id, required this.name, required this.phone, this.relation = ''});

  factory EmergencyContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EmergencyContact(
      id: doc.id,
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      relation: d['relation'] as String? ?? '',
    );
  }
}
