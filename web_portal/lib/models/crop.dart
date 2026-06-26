class Crop {
  final String id;
  final int? growthDurationDays;
  final double? baselineYieldPerHa;
  final double? baselinePricePerKg;

  String get displayName {
    if (id.isEmpty) return id;
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }

  Crop({
    required this.id,
    this.growthDurationDays,
    this.baselineYieldPerHa,
    this.baselinePricePerKg,
  });

  factory Crop.fromJson(Map<String, dynamic> json) {
    return Crop(
      id: json['id'],
      growthDurationDays: json['growth_duration_days'],
      baselineYieldPerHa: json['baseline_yield_per_ha']?.toDouble(),
      baselinePricePerKg: json['baseline_price_per_kg']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'growth_duration_days': growthDurationDays,
      'baseline_yield_per_ha': baselineYieldPerHa,
      'baseline_price_per_kg': baselinePricePerKg,
    };
  }
}
