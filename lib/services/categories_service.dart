import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ui_models.dart';

/// `categories/{id}` — the service taxonomy shown on the home dashboard /
/// "All Services" screen. Seeded once from the previous `demoCategories`
/// constant (see [seedIfEmpty]); after that it's a normal read-only
/// collection for the app (writes are console/admin-only per
/// firestore.rules).
class CategoriesService {
  CategoriesService._();
  static final CategoriesService instance = CategoriesService._();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('categories');

  Stream<List<ServiceCategory>> watchAll() {
    return _col.orderBy('order').snapshots().map((s) => s.docs.map(ServiceCategory.fromDoc).toList());
  }

  /// One-time seed so a fresh Firestore project isn't empty. Safe to call
  /// on every app start — firestore.rules only allows `categories` creates
  /// while the `_seeded` marker doc doesn't exist yet, and this writes that
  /// marker in the same batch, so every write attempt after the first one
  /// (from this device or any other) is rejected server-side, not just
  /// skipped client-side.
  Future<void> seedIfEmpty() async {
    final marker = await _col.doc('_seeded').get();
    if (marker.exists) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < seedCategories.length; i++) {
      final c = seedCategories[i];
      batch.set(_col.doc(), {'name': c.name, 'localName': c.localName, 'iconKey': c.iconKey, 'order': i});
    }
    batch.set(_col.doc('_seeded'), {'seededAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }
}
