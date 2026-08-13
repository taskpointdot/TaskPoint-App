import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/buttons.dart';
import '../models/app_user.dart' show CnicStatus;
import '../services/cnic_service.dart';
import '../services/session_controller.dart';
import 'cnic_camera_capture_screen.dart';

/// Maps to: cnic_verification_camera/code.html
///
/// Both seekers ("Mujhe Kaam Karwana Hai") and providers ("Mujhe Kaam
/// Karna Hai") land here right after picking a role on RoleSelectionScreen,
/// and must provide the FRONT and BACK of their CNIC before they can reach
/// their home screen — either by capturing it live with the device camera,
/// or by uploading an existing photo from storage.
///
/// "Capture" pushes [CnicCameraCaptureScreen], which opens a live camera
/// preview (via the `camera` plugin) so the shot is taken right there and
/// then — on Android this is the native camera, and on web it's
/// a live `getUserMedia` preview in-app, not the OS file/storage picker.
/// `image_picker`'s `ImageSource.camera` was used here before, but on
/// desktop web browsers ignore the `capture` attribute it relies on and
/// silently fall back to the regular file picker, which made "Capture" and
/// "Upload" behave identically. "Upload" still uses `image_picker` with
/// `ImageSource.gallery`, which correctly opens the photo library / file
/// picker on every platform.
class CnicVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const CnicVerificationScreen({super.key, required this.onVerified});

  @override
  State<CnicVerificationScreen> createState() => _CnicVerificationScreenState();
}

enum _CnicSide { front, back }

class _CnicVerificationScreenState extends State<CnicVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  bool _submitting = false;

  bool get _bothCaptured => _frontBytes != null && _backBytes != null;

  void _setSide(_CnicSide side, Uint8List bytes) {
    if (!mounted) return;
    setState(() {
      if (side == _CnicSide.front) {
        _frontBytes = bytes;
      } else {
        _backBytes = bytes;
      }
    });
  }

  /// Opens a live in-app camera preview and lets the user shoot the CNIC
  /// directly — this is what actually makes "Capture" open the camera
  /// instead of the storage/file picker.
  Future<void> _capture(_CnicSide side) async {
    try {
      final label = side == _CnicSide.front ? 'Front Side / Aagay Ka Hissa' : 'Back Side / Peechay Ka Hissa';
      final Uint8List? shot = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => CnicCameraCaptureScreen(label: label)),
      );
      if (shot == null) return; // user backed out of the camera
      _setSide(side, shot);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $e')),
      );
    }
  }

  /// Opens the device's photo library / file picker for an existing photo.
  Future<void> _upload(_CnicSide side) async {
    try {
      final XFile? shot = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (shot == null) return; // user backed out of the picker
      final bytes = await shot.readAsBytes();
      _setSide(side, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open storage: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_bothCaptured || _submitting) return;
    final uid = SessionController.instance.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await CnicService.instance.submit(uid: uid, frontBytes: _frontBytes!, backBytes: _backBytes!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CNIC uploaded — pending verification')),
      );
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(title: 'Shanaakhti Card Ki Tasdeeq'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Capture both sides of your CNIC', style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                'Apne CNIC ka aagay aur peechay wala hissa live camera se khinchain. Yeh tasdeeq seeker aur provider dono ke liye lazmi hai.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Surfaces the admin dashboard's decision. Without this a
              // rejected user just saw the blank capture form again with no
              // idea their submission had been reviewed, let alone why.
              ListenableBuilder(
                listenable: SessionController.instance,
                builder: (context, _) {
                  final me = SessionController.instance.user;
                  if (me == null) return const SizedBox.shrink();
                  if (me.cnicStatus == CnicStatus.pending) {
                    return _StatusBanner(
                      icon: Symbols.hourglass_top_rounded,
                      background: AppColors.statusAmberBg,
                      foreground: AppColors.statusAmberFg,
                      title: 'Under review',
                      body: 'Your CNIC has been submitted and is waiting for verification.',
                    );
                  }
                  if (me.cnicStatus == CnicStatus.rejected) {
                    return _StatusBanner(
                      icon: Symbols.error_rounded,
                      background: AppColors.errorContainer,
                      foreground: AppColors.onErrorContainer,
                      title: 'Verification rejected',
                      body: me.cnicRejectionReason?.isNotEmpty == true
                          ? '${me.cnicRejectionReason}\n\nPlease retake both sides and submit again.'
                          : 'Please retake both sides clearly and submit again.',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 8),
              _CnicCaptureCard(
                label: 'Front Side / Aagay Ka Hissa',
                bytes: _frontBytes,
                onCapture: () => _capture(_CnicSide.front),
                onUpload: () => _upload(_CnicSide.front),
              ),
              const SizedBox(height: 16),
              _CnicCaptureCard(
                label: 'Back Side / Peechay Ka Hissa',
                bytes: _backBytes,
                onCapture: () => _capture(_CnicSide.back),
                onUpload: () => _upload(_CnicSide.back),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _submitting ? 'Submitting...' : 'Tasdeeq Karain / Submit Verification',
                icon: Symbols.verified_user_rounded,
                onPressed: _bothCaptured && !_submitting ? _submit : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Your CNIC photos are used only to verify your identity.',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CnicCaptureCard extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onCapture;
  final VoidCallback onUpload;

  const _CnicCaptureCard({required this.label, required this.bytes, required this.onCapture, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final captured = bytes != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: captured ? AppColors.primary : AppColors.outlineVariant, width: captured ? 2 : 1),
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: captured
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(bytes!, fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Symbols.check_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: AppColors.surfaceContainer,
                    child: Center(child: Icon(Symbols.badge_rounded, size: 48, color: AppColors.outline)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: AppTextStyles.labelLg.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCapture,
                        icon: Icon(captured ? Symbols.replay_rounded : Symbols.photo_camera_rounded, size: 18),
                        label: Text(captured ? 'Retake' : 'Capture'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          // The app theme's default OutlinedButton style sets
                          // minimumSize: Size.fromHeight(48) (full-width), meant
                          // for standalone buttons in a Column. These sit
                          // inside a Row side by side, so it must override
                          // that back to a finite size or it crashes with
                          // "BoxConstraints forces an infinite width".
                          minimumSize: const Size(64, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onUpload,
                        icon: Icon(captured ? Symbols.drive_folder_upload_rounded : Symbols.upload_rounded, size: 18),
                        label: Text(captured ? 'Replace' : 'Upload'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          minimumSize: const Size(64, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Review-status banner shown above the capture cards, reflecting whatever
/// the admin dashboard's CNIC Verifications module last decided.
class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String body;

  const _StatusBanner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLg.copyWith(color: foreground)),
                const SizedBox(height: 2),
                Text(body, style: AppTextStyles.bodyMd.copyWith(color: foreground)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
