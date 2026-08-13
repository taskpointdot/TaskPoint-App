import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_service.dart';
import '../services/session_controller.dart';
import '../services/geo_utils.dart';
import '../services/dialer.dart';

/// Maps to: emergency_sos_countdown/code.html
/// There's no SMS/automated-calling integration (that's a device-level
/// action, not something Firebase does) — when the countdown finishes this
/// logs a real `sos_logs` entry with the user's real location, and shows
/// their real emergency contacts with one-tap call buttons instead of a
/// generic "help is on the way" message.
class EmergencySosCountdownScreen extends StatefulWidget {
  const EmergencySosCountdownScreen({super.key});

  @override
  State<EmergencySosCountdownScreen> createState() => _EmergencySosCountdownScreenState();
}

class _EmergencySosCountdownScreenState extends State<EmergencySosCountdownScreen> {
  static const _errorRed = Color(0xFFDC2626);
  static const _total = 5;
  int _secondsLeft = _total;
  bool _cancelled = false;
  bool _sent = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          _sent = true;
          _logSos();
        }
      });
    });
  }

  Future<void> _logSos() async {
    final uid = SessionController.instance.uid;
    if (uid == null) return;
    final position = await currentDevicePosition();
    await EmergencyService.instance.logSos(uid: uid, location: position);
  }

  void _cancel() {
    _timer?.cancel();
    setState(() => _cancelled = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      final uid = SessionController.instance.uid;
      return Scaffold(
        backgroundColor: _errorRed,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(Symbols.check_circle_rounded, color: Colors.white, fill: 1, size: 72),
                const SizedBox(height: AppSpacing.lg),
                Text('Alert Logged', style: AppTextStyles.headlineLgMobile.copyWith(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text('Call your emergency contacts now.', style: AppTextStyles.bodyLg.copyWith(color: Colors.white.withOpacity(0.9)), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: uid == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<EmergencyContact>>(
                          stream: EmergencyService.instance.watchContacts(uid),
                          builder: (context, snap) {
                            final contacts = snap.data ?? const [];
                            if (contacts.isEmpty) {
                              return Center(
                                child: Text('No emergency contacts saved', style: AppTextStyles.bodyLg.copyWith(color: Colors.white.withOpacity(0.9))),
                              );
                            }
                            return ListView.separated(
                              itemCount: contacts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                final c = contacts[i];
                                return Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(c.name, style: AppTextStyles.labelLg),
                                            Text(c.phone, style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () => callPhone(c.phone),
                                        style: ElevatedButton.styleFrom(backgroundColor: _errorRed, foregroundColor: Colors.white),
                                        icon: const Icon(Symbols.call_rounded, size: 18),
                                        label: const Text('Call'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white70, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    child: Text('Done', style: AppTextStyles.headlineMd.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = _cancelled ? 0.0 : _secondsLeft / _total;

    return Scaffold(
      backgroundColor: _errorRed,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Symbols.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
                  Expanded(
                    child: Text(
                      'EMERGENCY SOS',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMd.copyWith(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.warning_rounded, color: Colors.white, size: 56),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text(
                        _cancelled ? 'Alert canceled.' : 'Logging your location for emergency contacts...',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineMd.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 4,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          Container(
                            width: 190,
                            height: 190,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                _cancelled ? 'Canceled' : '$_secondsLeft',
                                style: TextStyle(
                                  fontSize: _cancelled ? 28 : 72,
                                  fontWeight: FontWeight.w900,
                                  color: _errorRed,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (!_cancelled)
                      SizedBox(
                        width: 280,
                        height: 64,
                        child: OutlinedButton.icon(
                          onPressed: _cancel,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
                          ),
                          icon: const Icon(Symbols.cancel_rounded, color: Colors.white),
                          label: Text('Cancel Alert', style: AppTextStyles.headlineMd.copyWith(color: Colors.white)),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (!_cancelled)
                      Text(
                        'Alert will be logged automatically when timer reaches zero.',
                        style: AppTextStyles.bodyMd.copyWith(color: Colors.white.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
