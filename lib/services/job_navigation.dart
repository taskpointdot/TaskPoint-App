import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/job.dart';
import '../screens/complete_job_photo_capture_screen.dart';
import '../screens/job_alert_detail_screen.dart';
import '../screens/job_completion_receipt_screen.dart';
import '../screens/job_in_progress_screen.dart';
import '../screens/track_customer_location_screen.dart';
import '../screens/track_worker_location_screen.dart';
import '../screens/worker_offers_inbox_screen.dart';
import 'jobs_service.dart';
import 'session_controller.dart';

/// Works out which screen a given job should open into, for whoever is
/// signed in.
///
/// The two sides of a job want completely different screens at the same
/// status — at `accepted` the seeker wants the tracking map and the worker
/// wants their own en-route screen — and the same job can be reached from
/// My Jobs, the notifications inbox, or a job alert. Centralising the
/// mapping keeps those entry points from drifting apart (they already had:
/// My Jobs sent `accepted` jobs to the in-progress screen while the offers
/// inbox sent them somewhere else again).
Widget? screenForJob(Job job, {required UserRole? role}) {
  final isWorker = role == UserRole.worker;
  return switch (job.status) {
    // Still collecting bids: the seeker reviews offers, the worker reads the
    // posting and decides whether to bid.
    JobStatus.posted || JobStatus.negotiating =>
      isWorker ? JobAlertDetailScreen(jobId: job.id) : WorkerOffersInboxScreen(jobId: job.id),
    // Worker assigned and travelling — both sides get a live map, each
    // centred on the other party.
    JobStatus.accepted =>
      isWorker ? TrackCustomerLocationScreen(jobId: job.id) : TrackWorkerLocationScreen(jobId: job.id),
    // Worker has arrived: they finish it with before/after photos, the
    // seeker watches status and has the SOS panel.
    JobStatus.inProgress =>
      isWorker ? CompleteJobPhotoCaptureScreen(jobId: job.id) : JobInProgressScreen(jobId: job.id),
    JobStatus.completed => JobCompletionReceiptScreen(jobId: job.id),
    // Nothing meaningful sits behind a cancelled job.
    JobStatus.cancelled => null,
  };
}

/// Fetches [jobId] and pushes whatever [screenForJob] picks for it. Used by
/// entry points that only carry an id (notifications), not a whole [Job].
///
/// Silently does nothing when the job has been deleted or is cancelled —
/// there's no screen worth showing, and a notification about a job that no
/// longer exists shouldn't throw.
Future<void> openJobById(BuildContext context, String jobId) async {
  final job = await JobsService.instance.getJob(jobId);
  if (job == null || !context.mounted) return;
  final screen = screenForJob(job, role: SessionController.instance.user?.role);
  if (screen == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
