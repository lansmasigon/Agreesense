class MarketPrice {
  final String cropId;
  final String market;
  final double pricePerKg;
  final DateTime recordedOn;

  MarketPrice({
    required this.cropId,
    required this.market,
    required this.pricePerKg,
    required this.recordedOn,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      cropId: json['crop_id'],
      market: json['market'],
      pricePerKg: json['price_per_kg']?.toDouble() ?? 0.0,
      recordedOn: DateTime.parse(json['recorded_on']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'crop_id': cropId,
      'market': market,
      'price_per_kg': pricePerKg,
      'recorded_on': recordedOn.toIso8601String(),
    };
  }
}
