/// Full detail for a single pattern (approved design screen #3, "Design
/// detail"): preview, engineering metadata, and the three approved
/// badges (SVG ready, DXF status, cut-ready geometry) — the DXF badge
/// only ever reflects existence/status, never the file path itself
/// (that stays behind `pattern_assets` RLS and, for drafts, the
/// `staff_get_draft_dxf_path()` function from PG-005).
class PatternDetail {
  const PatternDetail({
    required this.id,
    required this.pglcCode,
    required this.name,
    required this.categoryName,
    required this.categoryDescription,
    required this.typicalUses,
    required this.engineeringNote,
    required this.minThicknessMm,
    required this.hasSvg,
    required this.hasDxf,
    required this.previewPath,
    required this.isFavourited,
    required this.savedCount,
  });

  final String id;
  final String pglcCode;
  final String name;
  final String categoryName;
  final String? categoryDescription;
  final String? typicalUses;
  final String? engineeringNote;
  final double? minThicknessMm;
  final bool hasSvg;
  final bool hasDxf;
  final String? previewPath;
  final bool isFavourited;
  final int savedCount;

  factory PatternDetail.fromJson(
    Map<String, dynamic> json, {
    required bool isFavourited,
    required int savedCount,
  }) {
    final category = json['pattern_categories'] as Map<String, dynamic>?;
    final assets = (json['pattern_assets'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    String? previewPath;
    var hasSvg = false;
    var hasDxf = false;
    for (final asset in assets) {
      final type = asset['asset_type'] as String?;
      if (type == 'preview') previewPath = asset['storage_path'] as String?;
      if (type == 'svg') hasSvg = true;
      if (type == 'dxf')
        hasDxf =
            true; // row visible at all ⇒ staff viewer; customers never see dxf rows (PG-005)
    }
    return PatternDetail(
      id: json['id'] as String,
      pglcCode: json['pglc_code'] as String,
      name: json['name'] as String,
      categoryName: category?['name'] as String? ?? '',
      categoryDescription: category?['description'] as String?,
      typicalUses: json['typical_uses'] as String?,
      engineeringNote: json['engineering_note'] as String?,
      minThicknessMm: (category?['min_thickness_mm'] as num?)?.toDouble(),
      hasSvg: hasSvg,
      hasDxf: hasDxf,
      previewPath: previewPath,
      isFavourited: isFavourited,
      savedCount: savedCount,
    );
  }
}
