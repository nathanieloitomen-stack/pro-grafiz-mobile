import 'package:supabase_flutter/supabase_flutter.dart';

/// One payment record, as shown on both the customer's job detail (own
/// payments) and the staff Payments screen (approved design #17).
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.jobId,
    required this.jobRef,
    required this.kind,
    required this.amountKobo,
    required this.status,
    this.bankReference,
  });

  final String id;
  final String jobId;
  final String jobRef;
  final String kind;
  final int amountKobo;
  final String status;
  final String? bankReference;

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final job = json['jobs'] as Map<String, dynamic>?;
    return PaymentRecord(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      jobRef: job?['job_ref'] as String? ?? '',
      kind: json['kind'] as String,
      amountKobo: (json['amount_kobo'] as num).toInt(),
      status: json['status'] as String,
      bankReference: json['bank_reference'] as String?,
    );
  }
}

/// Thin wrapper around the PG-009 Edge Functions and read-only queries.
/// No provider integration exists — see docs/payments.md: no gateway is
/// specified, so this only covers the manual bank-transfer flow.
///
/// UNTESTED against a live backend.
class PaymentRepository {
  PaymentRepository(this._client);

  final SupabaseClient _client;

  Future<PaymentRecord?> fetchLatestForJob(String jobId, String kind) async {
    final row = await _client
        .from('payments')
        .select(
            'id, job_id, kind, amount_kobo, status, bank_reference, jobs(job_ref)')
        .eq('job_id', jobId)
        .eq('kind', kind)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : PaymentRecord.fromJson(row);
  }

  Future<PaymentRecord> requestPayment(
      {required String jobId, required String kind}) async {
    final response = await _client.functions.invoke(
      'create-payment-request',
      body: {'job_id': jobId, 'kind': kind},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
    return PaymentRecord.fromJson(data['payment'] as Map<String, dynamic>);
  }

  /// Staff view — RLS (`payments_select_own_or_finance_staff`, PG-005)
  /// determines what's actually returned; this makes no access
  /// decisions of its own.
  Future<List<PaymentRecord>> fetchStaffPayments() async {
    final rows = await _client
        .from('payments')
        .select(
            'id, job_id, kind, amount_kobo, status, bank_reference, jobs(job_ref)')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> triage(
      {required String paymentId,
      required String result,
      String? bankReference}) async {
    final response = await _client.functions.invoke(
      'triage-payment',
      body: {
        'payment_id': paymentId,
        'result': result,
        if (bankReference != null) 'bank_reference': bankReference
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
  }

  Future<void> confirm({required String paymentId, required String pin}) async {
    final response = await _client.functions.invoke(
      'confirm-payment',
      body: {'payment_id': paymentId, 'pin': pin},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
  }
}
