import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads CNIC front/back photos to Storage and flips the owning user's
/// `cnicStatus` to 'pending'. There's no OCR/automated verification (out of
/// scope) and no admin dashboard yet to approve it — a real human has to
/// flip `cnicStatus` to 'verified'/'rejected' by hand in the Firebase
/// console until that's built.
class CnicService {
  CnicService._();
  static final CnicService instance = CnicService._();

  Future<void> submit({required String uid, required Uint8List frontBytes, required Uint8List backBytes}) async {
    final frontRef = FirebaseStorage.instance.ref('cnic/$uid/front.jpg');
    final backRef = FirebaseStorage.instance.ref('cnic/$uid/back.jpg');
    await frontRef.putData(frontBytes, SettableMetadata(contentType: 'image/jpeg'));
    await backRef.putData(backBytes, SettableMetadata(contentType: 'image/jpeg'));
    final frontUrl = await frontRef.getDownloadURL();
    final backUrl = await backRef.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'cnicStatus': 'pending',
      'cnicFrontUrl': frontUrl,
      'cnicBackUrl': backUrl,
    });
  }
}
