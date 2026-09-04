/// One entry in the customer's job list (approved screen #7, "Jobs").
class JobSummary {
  const JobSummary({
    required this.id,
    required this.jobRef,
    required this.currentStage,
    required this.status,
  });

  final String id;
  final String jobRef;
  final String currentStage;
  final String status;

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    return JobSummary(
      id: json['id'] as String,
      jobRef: json['job_ref'] as String,
      currentStage: json['current_stage'] as String,
      status: json['status'] as String,
    );
  }
}

/// The eight approved stages, in order (Master Spec §9) — used to
/// render the timeline and to compute how far along a job is.
const jobStages = [
  'SUBMITTED',
  'PAYMENT_CONFIRMED',
  'DESIGN_IN_PROGRESS',
  'DESIGN_SENT_FOR_APPROVAL',
  'IN_PRODUCTION',
  'READY_FOR_DISPATCH',
  'DISPATCHED',
  'RELEASED',
];

class JobDetail {
  const JobDetail({
    required this.id,
    required this.jobRef,
    required this.currentStage,
    required this.status,
    this.holdReason,
    this.holdNote,
    this.cancelReason,
    this.cancelNote,
    this.hasReleasedDraft = false,
    this.previewPath,
    this.totalKobo,
  });

  final String id;
  final String jobRef;
  final String currentStage;
  final String status;
  final String? holdReason;
  final String? holdNote;
  final String? cancelReason;
  final String? cancelNote;
  final bool hasReleasedDraft;
  final String? previewPath;
  final int? totalKobo;

  factory JobDetail.fromJson(
    Map<String, dynamic> json, {
    required bool hasReleasedDraft,
    String? previewPath,
    int? totalKobo,
  }) {
    return JobDetail(
      id: json['id'] as String,
      jobRef: json['job_ref'] as String,
      currentStage: json['current_stage'] as String,
      status: json['status'] as String,
      holdReason: json['hold_reason'] as String?,
      holdNote: json['hold_note'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      cancelNote: json['cancel_note'] as String?,
      hasReleasedDraft: hasReleasedDraft,
      previewPath: previewPath,
      totalKobo: totalKobo,
    );
  }
}
