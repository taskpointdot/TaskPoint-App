import 'package:url_launcher/url_launcher.dart';

/// Opens the device's phone dialer with [phone] pre-filled. Used by every
/// "Call" button that used to be a no-op `onPressed: () {}`.
Future<void> callPhone(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  await launchUrl(uri);
}
