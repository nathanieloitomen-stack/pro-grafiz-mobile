/// A pattern as shown in the browse grid (approved design screen #2,
/// "Patterns"). Mirrors `patterns` joined to its preview
/// `pattern_assets` row and `pattern_favourite_counts`.
class PatternSummary {
  const PatternSummary({
    required this.id,
    required this.pglcCode,
    required this.name,
    required this.categoryName,
    required this.savedCount,
    this.previewPath,
    this.isFavourited = false,
  });

  final String id;
  final String pglcCode;
  final String name;
  final String categoryName;
  final int savedCount;
  final String? previewPath;
  final bool isFavourited;

  factory PatternSummary.fromJson(Map<String, dynamic> json, {required int savedCount, required bool isFavourited}) {
    final category = json['pattern_categories'] as Map<String, dynamic>?;
    final assets = (json['pattern_assets'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final preview = assets.where((a) => a['asset_type'] == 'preview').cast<Map<String, dynamic>?>().firstWhere(
          (_) => true,
          orElse: () => null,
        );
    return PatternSummary(
      id: json['id'] as String,
      pglcCode: json['pglc_code'] as String,
      name: json['name'] as String,
      categoryName: category?['name'] as String? ?? '',
      savedCount: savedCount,
      previewPath: preview?['storage_path'] as String?,
      isFavourited: isFavourited,
    );
  }

  PatternSummary copyWith({bool? isFavourited, int? savedCount}) {
    return PatternSummary(
      id: id,
      pglcCode: pglcCode,
      name: name,
      categoryName: categoryName,
      savedCount: savedCount ?? this.savedCount,
      previewPath: previewPath,
      isFavourited: isFavourited ?? this.isFavourited,
    );
  }
}
