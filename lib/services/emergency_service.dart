import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_contact.dart';

/// Emergency contacts (`users/{uid}/emergencyContacts`) and SOS event log
/// (`sos_logs`). There's no SMS/automated-calling integration here — that's
/// a device-level action, not something Firebase does — so "alerting"
/// contacts means surfacing real contacts with a tappable phone number,
/// and logging the SOS event with the user's real location.
class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contacts(String uid) =>
      _db.collection('users').doc(uid).collection('emergencyContacts');

  Stream<List<EmergencyContact>> watchContacts(String uid) {
    return _contacts(uid).snapshots().map((s) => s.docs.map(EmergencyContact.fromDoc).toList());
  }

  Future<void> addContact({required String uid, required String name, required String phone, String relation = ''}) {
    return _contacts(uid).add({'name': name, 'phone': phone, 'relation': relation});
  }

  Future<void> deleteContact({required String uid, required String contactId}) {
    return _contacts(uid).doc(contactId).delete();
  }

  Future<String> logSos({required String uid, GeoPoint? location}) async {
    final doc = await _db.collection('sos_logs').add({
      'userId': uid,
      'location': location,
      'resolved': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> resolveSos(String sosLogId) => _db.collection('sos_logs').doc(sosLogId).update({'resolved': true});
}
