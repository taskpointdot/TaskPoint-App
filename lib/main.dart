import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_settings_controller.dart';
import 'services/auth_service.dart';
import 'services/session_controller.dart';
import 'services/jobs_service.dart';
import 'services/geo_utils.dart';
import 'widgets/post_job_sheet.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_find_help_screen.dart';
import 'screens/phone_number_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/cnic_verification_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/home_voice_job_posting_screen.dart';
import 'screens/voice_search_screen.dart';
import 'screens/ai_assistant_chat_screen.dart';
import 'screens/request_success_screen.dart';
import 'screens/my_jobs_tracking_screen.dart';
import 'screens/transaction_details_screen.dart';
import 'screens/profile_settings_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/no_emergency_contacts_screen.dart';
import 'screens/emergency_sos_countdown_screen.dart';
import 'screens/worker_home_dashboard_screen.dart';
import 'screens/earnings_wallet_dashboard_screen.dart';
import 'screens/digital_wallet_top_up_screen.dart';
import 'screens/job_history_list_screen.dart';
import 'screens/notifications_inbox_screen.dart';
import 'screens/performance_insights_screen.dart';
import 'screens/profile_settings_worker_screen.dart';
import 'screens/report_a_problem_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TaskPointApp());
}

/// Central route table for the whole app. Every screen in lib/screens is
/// registered here under a named route, so it's reachable with
/// `Navigator.of(context).pushNamed('/route-name')` from anywhere instead of
/// only ever being reachable if some other screen happens to import it
/// directly. See each route's comment for where it fits in the user flow.
class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const phoneNumber = '/phone-number';
  static const otp = '/otp';
  static const roleSelection = '/role-selection';
  static const cnicVerification = '/cnic-verification';

  // Seeker ("Mujhe Kaam Karwana Hai") flow
  static const home = '/home';
  static const homeVoiceJobPosting = '/home-voice-job-posting';
  static const voiceSearch = '/voice-search';
  static const aiAssistantChat = '/ai-assistant-chat';
  static const jobAlertDetail = '/job-alert-detail';
  static const counterOffer = '/counter-offer';
  static const workerProfileDetail = '/worker-profile-detail';
  static const requestSuccess = '/request-success';
  static const workerOffersInbox = '/worker-offers-inbox';
  static const trackWorkerLocation = '/track-worker-location';
  static const jobInProgress = '/job-in-progress';
  static const jobCompletedReview = '/job-completed-review';
  static const myJobsTracking = '/my-jobs-tracking';
  static const transactionDetails = '/transaction-details';
  static const profileSettings = '/profile-settings';
  static const emergencyContacts = '/emergency-contacts';
  static const noEmergencyContacts = '/no-emergency-contacts';
  static const emergencySosCountdown = '/emergency-sos-countdown';

  // Worker ("Mujhe Kaam Karna Hai") flow
  static const workerHome = '/worker-home';
  static const workerCustomerChat = '/worker-customer-chat';
  static const completeJobPhotoCapture = '/complete-job-photo-capture';
  static const jobCompletionReceipt = '/job-completion-receipt';
  static const jobNotificationPopup = '/job-notification-popup';
  static const negotiatePrice = '/negotiate-price';
  static const trackCustomerLocation = '/track-customer-location';
  static const earningsWallet = '/earnings-wallet';
  static const walletTopUp = '/wallet-top-up';
  static const jobHistory = '/job-history';
  static const notificationsInbox = '/notifications-inbox';
  static const performanceInsights = '/performance-insights';
  static const workerProfileSettings = '/worker-profile-settings';
  static const reportProblem = '/report-problem';
}

class TaskPointApp extends StatelessWidget {
  const TaskPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app whenever AppSettingsController's theme mode
    // (or language) changes — see the Dark Mode switch and English/Roman
    // Urdu toggle on ProfileSettingsScreen.
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'TaskPoint',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: AppSettingsController.instance.themeMode,
          initialRoute: AppRoutes.splash,
          routes: {
        AppRoutes.splash: (_) => const SplashScreen(),

        // Onboarding carousel -> phone number entry -> OTP verification -> pick a role.
        // (Onboarding stays on the stack via a normal push, not a replace,
        // so the back arrow on the phone-number screen can pop back to it.)
        AppRoutes.onboarding: (context) => OnboardingFindHelpScreen(
              onNext: () => Navigator.of(context).pushNamed(AppRoutes.phoneNumber),
              onSkip: () => Navigator.of(context).pushNamed(AppRoutes.phoneNumber),
            ),
        // Kicks off real Firebase Phone Auth: sends the SMS, then pushes the
        // OTP screen with the verificationId Firebase handed back. Auto-
        // verification (Android instant SMS retrieval) skips the OTP screen
        // entirely and signs straight in.
        AppRoutes.phoneNumber: (context) => PhoneNumberScreen(
              onContinue: (phone) async {
                final e164 = '+92${phone.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^92'), '')}';
                final completer = Completer<void>();
                // Mutable and shared by reference with onSubmit/onResend below
                // (not captured by value), so a resend's fresh id is what
                // onSubmit actually verifies against, not the original one.
                String? verificationId;
                await AuthService.instance.sendOtp(
                  phone: e164,
                  codeSent: (id) {
                    verificationId = id;
                    if (completer.isCompleted) return;
                    completer.complete();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OtpVerificationScreen(
                          phoneNumber: phone,
                          onSubmit: (code) async {
                            final cred = await AuthService.instance.confirmOtp(verificationId: verificationId!, smsCode: code);
                            await AuthService.instance.ensureUserDocument(uid: cred.user!.uid, phone: e164);
                          },
                          onResend: () => AuthService.instance.sendOtp(
                            phone: e164,
                            codeSent: (id) => verificationId = id,
                            onAutoVerified: (_) {},
                            onFailed: (_) {},
                          ),
                          onVerified: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(SessionController.instance.startRoute, (route) => false),
                        ),
                      ),
                    );
                  },
                  onAutoVerified: (credential) async {
                    if (!completer.isCompleted) completer.complete();
                    await AuthService.instance.ensureUserDocument(uid: credential.user!.uid, phone: e164);
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(SessionController.instance.startRoute, (route) => false);
                    }
                  },
                  onFailed: (message) {
                    if (!completer.isCompleted) completer.completeError(AuthException(message));
                  },
                );
                return completer.future;
              },
            ),
        // Reachable directly (e.g. deep link); real OTP always needs a
        // verificationId from a just-sent SMS, so this just restarts the
        // phone-entry step instead of faking a code screen.
        AppRoutes.otp: (context) => Builder(builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.phoneNumber);
              });
              return const Scaffold(body: SizedBox.shrink());
            }),
        AppRoutes.roleSelection: (_) => const RoleSelectionScreen(),
        // Reachable directly (e.g. deep link); defaults to the seeker home.
        AppRoutes.cnicVerification: (context) => CnicVerificationScreen(
              onVerified: () => Navigator.of(context).pushReplacementNamed(AppRoutes.home),
            ),

        // Seeker side
        AppRoutes.home: (_) => const HomeDashboardScreen(),
        AppRoutes.homeVoiceJobPosting: (context) => HomeVoiceJobPostingScreen(
              // Was pushing the AI chat, which recorded nothing — the mic
              // was decorative. Now opens live speech recognition.
              onMicTap: () => Navigator.of(context).pushNamed(AppRoutes.voiceSearch),
              onCategoryTap: (category) async {
                final uid = SessionController.instance.uid;
                if (uid == null) return;
                final details = await showPostJobSheet(context, categoryName: category.name, categoryIcon: category.icon);
                if (details == null || !context.mounted) return;
                final position = await currentDevicePosition();
                final jobId = await JobsService.instance.postJob(
                  seekerId: uid,
                  categoryId: category.id.isEmpty ? null : category.id,
                  categoryName: category.name,
                  description: details.description,
                  budget: details.budget,
                  location: position,
                );
                if (context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestSuccessScreen(jobId: jobId)));
                }
              },
            ),
        AppRoutes.voiceSearch: (_) => const VoiceSearchScreen(),
        AppRoutes.aiAssistantChat: (_) => const AiAssistantChatScreen(),
        // jobAlertDetail, counterOffer, workerProfileDetail, workerOffersInbox,
        // trackWorkerLocation, jobInProgress, jobCompletedReview,
        // workerCustomerChat, completeJobPhotoCapture, jobCompletionReceipt,
        // jobNotificationPopup, negotiatePrice, trackCustomerLocation all now
        // require a real jobId/workerId a static route can't supply — they're
        // reached only via an explicit MaterialPageRoute push with that id
        // from wherever the job/worker is actually known (see each screen's
        // callers), not via Navigator.pushNamed. Same for requestSuccess.
        AppRoutes.myJobsTracking: (_) => const MyJobsTrackingScreen(),
        AppRoutes.transactionDetails: (_) => const TransactionDetailsScreen(),
        AppRoutes.profileSettings: (_) => const ProfileSettingsScreen(),
        AppRoutes.emergencyContacts: (_) => const EmergencyContactsScreen(),
        AppRoutes.noEmergencyContacts: (_) => const NoEmergencyContactsScreen(),
        AppRoutes.emergencySosCountdown: (_) => const EmergencySosCountdownScreen(),

        // Worker side
        AppRoutes.workerHome: (_) => const WorkerHomeDashboardScreen(),
        AppRoutes.earningsWallet: (_) => const EarningsWalletDashboardScreen(),
        AppRoutes.walletTopUp: (_) => const DigitalWalletTopUpScreen(),
        AppRoutes.jobHistory: (_) => const JobHistoryListScreen(),
        AppRoutes.notificationsInbox: (_) => const NotificationsInboxScreen(),
        AppRoutes.performanceInsights: (_) => const PerformanceInsightsScreen(),
        AppRoutes.workerProfileSettings: (_) => const ProfileSettingsWorkerScreen(),
        AppRoutes.reportProblem: (_) => const ReportAProblemScreen(),
          },
        );
      },
    );
  }
}
