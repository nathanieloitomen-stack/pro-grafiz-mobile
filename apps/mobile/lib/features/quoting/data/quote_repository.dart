import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a live quote estimate — mirrors the `estimate-quote` Edge
/// Function's response exactly (PG-007). `available: false` is a normal,
/// expected state (no pricing configured yet), not an error — the UI
/// should show [reason] as an honest explanation, never fall back to a
/// placeholder number.
class QuoteEstimate {
  const QuoteEstimate(
      {required this.available,
      this.reason,
      this.totalKobo,
      this.depositKobo,
      this.balanceKobo});

  final bool available;
  final String? reason;
  final int? totalKobo;
  final int? depositKobo;
  final int? balanceKobo;

  factory QuoteEstimate.fromJson(Map<String, dynamic> json) {
    return QuoteEstimate(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
      totalKobo: (json['totalKobo'] as num?)?.toInt(),
      depositKobo: (json['depositKobo'] as num?)?.toInt(),
      balanceKobo: (json['balanceKobo'] as num?)?.toInt(),
    );
  }
}

/// Thin wrapper around the PG-007 quote-engine Edge Functions.
/// UNTESTED against a live backend.
class QuoteRepository {
  QuoteRepository(this._client);

  final SupabaseClient _client;

  /// Public — no session required, matching estimate-quote's own design
  /// (a live estimate while configuring shouldn't need sign-in).
  Future<QuoteEstimate> estimate({
    required String materialId,
    required String finishId,
    required double thicknessMm,
    required double widthMm,
    required double heightMm,
    int quantity = 1,
  }) async {
    final response = await _client.functions.invoke(
      'estimate-quote',
      body: {
        'material_id': materialId,
        'finish_id': finishId,
        'thickness_mm': thicknessMm,
        'width_mm': widthMm,
        'height_mm': heightMm,
        'quantity': quantity,
      },
    );
    return QuoteEstimate.fromJson(response.data as Map<String, dynamic>);
  }
}
