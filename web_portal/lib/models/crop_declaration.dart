class CropDeclaration {
  final String id;
  final String farmerId;
  final String cropId;
  final double areaPlanted;
  final DateTime datePlanted;
  final DateTime estimatedHarvestDate;
  final String status;

  CropDeclaration({
    required this.id,
    required this.farmerId,
    required this.cropId,
    required this.areaPlanted,
    required this.datePlanted,
    required this.estimatedHarvestDate,
    required this.status,
  });

  factory CropDeclaration.fromJson(Map<String, dynamic> json) {
    return CropDeclaration(
      id: json['id'],
      farmerId: json['farmer_id'],
      cropId: json['crop_id'],
      areaPlanted: json['area_ha']?.toDouble() ?? 0.0,
      datePlanted: DateTime.parse(json['planting_date']),
      estimatedHarvestDate: DateTime.parse(json['expected_harvest_date']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmer_id': farmerId,
      'crop_id': cropId,
      'area_ha': areaPlanted,
      'planting_date': datePlanted.toIso8601String(),
      'expected_harvest_date': estimatedHarvestDate.toIso8601String(),
      'status': status,
    };
  }
}
