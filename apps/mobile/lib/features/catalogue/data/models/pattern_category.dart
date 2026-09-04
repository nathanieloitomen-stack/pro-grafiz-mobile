/// A PGLC pattern category (e.g. "Geometric Lattice", "Islamic Star").
/// Mirrors `pattern_categories` — see docs/database-schema.md.
class PatternCategory {
  const PatternCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  factory PatternCategory.fromJson(Map<String, dynamic> json) {
    return PatternCategory(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}
