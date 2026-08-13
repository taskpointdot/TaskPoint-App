import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'job.dart' show categoryIconFor;

/// A `categories/{id}` Firestore document — the service taxonomy shown on
/// the home dashboard / "All Services" screen.
class ServiceCategory {
  final String id;
  final String name;
  final String localName;
  final String iconKey;

  const ServiceCategory({this.id = '', required this.name, required this.localName, required this.iconKey});

  IconData get icon => categoryIconFor(iconKey);

  factory ServiceCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ServiceCategory(
      id: doc.id,
      name: d['name'] as String? ?? '',
      localName: d['localName'] as String? ?? '',
      iconKey: d['iconKey'] as String? ?? '',
    );
  }
}

/// The first few categories shown directly on the home dashboard grid,
/// before the user taps "See All" to browse the full list above.
const int homeDashboardCategoryPreviewCount = 6;

/// Used only once, by [CategoriesService.seedIfEmpty], to populate a fresh
/// Firestore project's `categories` collection. Not read by any screen —
/// every screen reads live from Firestore via `CategoriesService.watchAll()`.
const List<ServiceCategory> seedCategories = [
  ServiceCategory(name: 'Plumber', localName: 'Mistri', iconKey: 'plumber'),
  ServiceCategory(name: 'Electrician', localName: 'Bijli wala', iconKey: 'electrician'),
  ServiceCategory(name: 'Carpenter', localName: 'Tarkhan', iconKey: 'carpenter'),
  ServiceCategory(name: 'Painter', localName: 'Rang saz', iconKey: 'painter'),
  ServiceCategory(name: 'Mason', localName: 'Raj', iconKey: 'mason'),
  ServiceCategory(name: 'Cleaner', localName: 'Safai wala', iconKey: 'cleaner'),
  ServiceCategory(name: 'AC Repair', localName: 'AC mistri', iconKey: 'ac repair'),
  ServiceCategory(name: 'Appliance Repair', localName: 'Appliance thk karna', iconKey: 'appliance repair'),
  ServiceCategory(name: 'Gardener', localName: 'Mali', iconKey: 'gardener'),
  ServiceCategory(name: 'Mover/Shifting', localName: 'Saman shift karna', iconKey: 'mover'),
  ServiceCategory(name: 'Pest Control', localName: 'Keeray maaray', iconKey: 'pest control'),
  ServiceCategory(name: 'Car Wash', localName: 'Gari dhona', iconKey: 'car wash'),
];
