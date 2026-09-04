/// A material option (e.g. "Mild Steel"), with its available
/// thicknesses. Mirrors `materials` + `material_thicknesses`.
class MaterialOption {
  const MaterialOption({
    required this.id,
    required this.code,
    required this.name,
    required this.thicknesses,
  });

  final String id;
  final String code;
  final String name;
  final List<double> thicknesses;

  factory MaterialOption.fromJson(Map<String, dynamic> json) {
    final thicknessRows = (json['material_thicknesses'] as List<dynamic>? ?? []);
    return MaterialOption(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      thicknesses: thicknessRows
          .map((e) => (e as Map<String, dynamic>)['thickness_mm'])
          .map((v) => (v as num).toDouble())
          .toList()
        ..sort(),
    );
  }
}

/// A finish option (e.g. "Powder Coat"). Mirrors `finishes`.
class FinishOption {
  const FinishOption({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory FinishOption.fromJson(Map<String, dynamic> json) {
    return FinishOption(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
    );
  }
}
