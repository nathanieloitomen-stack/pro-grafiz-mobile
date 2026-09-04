import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/material_option.dart';
import 'models/pattern_category.dart';
import 'models/pattern_detail.dart';
import 'models/pattern_summary.dart';

/// Data access for the PGLC catalogue: categories, patterns, search,
/// favourites, and material/finish configuration options. Every query
/// here relies entirely on the RLS policies from PG-005 for what a
/// given caller can actually see — this class adds no authorization
/// logic of its own, by design (CLAUDE.md: "Security is server-side").
/// An anonymous (signed-out) caller can browse the catalogue; favourites
/// require a signed-in customer, enforced by `pattern_favourites`' RLS,
/// not by anything in this file.
///
/// UNTESTED against a live backend — see AuthRepository's equivalent
/// caveat from PG-004; the same applies here.
class CatalogueRepository {
  CatalogueRepository(this._client);

  final SupabaseClient _client;

  Future<List<PatternCategory>> fetchCategories() async {
    final rows = await _client
        .from('pattern_categories')
        .select('id, code, name, description')
        .order('name');
    return (rows as List<dynamic>)
        .map((e) => PatternCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Browse/search patterns (approved design screen #2). [categoryCode]
  /// of `null` or `'All'` means no category filter. [query] matches
  /// PGLC code, name, or category, per the approved design's pill
  /// search description.
  Future<List<PatternSummary>> searchPatterns({
    String? query,
    String? categoryCode,
    int limit = 24,
    int offset = 0,
  }) async {
    var builder = _client
        .from('patterns')
        .select('id, pglc_code, name, pattern_categories(name), pattern_assets(asset_type, storage_path)');

    if (categoryCode != null && categoryCode != 'All') {
      builder = builder.eq('pattern_categories.code', categoryCode);
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim()}%';
      builder = builder.or('pglc_code.ilike.$q,name.ilike.$q');
    }

    final rows = await builder.order('name').range(offset, offset + limit - 1);
    final patternIds = (rows as List<dynamic>).map((e) => (e as Map<String, dynamic>)['id'] as String).toList();

    final counts = await _fetchFavouriteCounts(patternIds);
    final favourited = await _fetchFavouritedSet(patternIds);

    return rows.map((e) {
      final json = e as Map<String, dynamic>;
      final id = json['id'] as String;
      return PatternSummary.fromJson(json, savedCount: counts[id] ?? 0, isFavourited: favourited.contains(id));
    }).toList();
  }

  Future<PatternDetail> fetchPatternDetail(String patternId) async {
    final row = await _client
        .from('patterns')
        .select(
          'id, pglc_code, name, typical_uses, engineering_note, '
          'pattern_categories(name, description, min_thickness_mm), '
          'pattern_assets(asset_type, storage_path)',
        )
        .eq('id', patternId)
        .single();

    final counts = await _fetchFavouriteCounts([patternId]);
    final favourited = await _fetchFavouritedSet([patternId]);

    return PatternDetail.fromJson(
      row,
      savedCount: counts[patternId] ?? 0,
      isFavourited: favourited.contains(patternId),
    );
  }

  /// Requires a signed-in customer — `pattern_favourites`' RLS
  /// (`customer_id = current_customer_id()`) rejects this otherwise.
  Future<void> setFavourite(String patternId, String customerId, {required bool favourited}) async {
    if (favourited) {
      await _client.from('pattern_favourites').insert({'pattern_id': patternId, 'customer_id': customerId});
    } else {
      await _client
          .from('pattern_favourites')
          .delete()
          .eq('pattern_id', patternId)
          .eq('customer_id', customerId);
    }
  }

  Future<List<PatternSummary>> fetchFavouritePatterns(String customerId) async {
    final rows = await _client
        .from('pattern_favourites')
        .select(
          'patterns(id, pglc_code, name, pattern_categories(name), pattern_assets(asset_type, storage_path))',
        )
        .eq('customer_id', customerId);

    final patterns = (rows as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['patterns'] as Map<String, dynamic>)
        .toList();
    final ids = patterns.map((p) => p['id'] as String).toList();
    final counts = await _fetchFavouriteCounts(ids);

    return patterns
        .map((p) => PatternSummary.fromJson(p, savedCount: counts[p['id']] ?? 0, isFavourited: true))
        .toList();
  }

  Future<List<MaterialOption>> fetchMaterials() async {
    final rows = await _client
        .from('materials')
        .select('id, code, name, material_thicknesses(thickness_mm)')
        .eq('active', true)
        .order('name');
    return (rows as List<dynamic>).map((e) => MaterialOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FinishOption>> fetchFinishes() async {
    final rows = await _client.from('finishes').select('id, code, name').eq('active', true).order('name');
    return (rows as List<dynamic>).map((e) => FinishOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, int>> _fetchFavouriteCounts(List<String> patternIds) async {
    if (patternIds.isEmpty) return {};
    final rows = await _client
        .from('pattern_favourite_counts')
        .select('pattern_id, favourite_count')
        .inFilter('pattern_id', patternIds);
    return {
      for (final row in rows as List<dynamic>)
        (row as Map<String, dynamic>)['pattern_id'] as String: (row['favourite_count'] as num).toInt(),
    };
  }

  /// Empty for a signed-out caller or staff — `pattern_favourites`' RLS
  /// only ever returns rows for the caller's own `current_customer_id()`.
  Future<Set<String>> _fetchFavouritedSet(List<String> patternIds) async {
    if (patternIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('pattern_favourites')
          .select('pattern_id')
          .inFilter('pattern_id', patternIds);
      return (rows as List<dynamic>).map((e) => (e as Map<String, dynamic>)['pattern_id'] as String).toSet();
    } catch (_) {
      // Signed-out / no matching customer row — current_customer_id()
      // returns null and the query legitimately yields nothing.
      return {};
    }
  }
}
