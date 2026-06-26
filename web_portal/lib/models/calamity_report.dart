class CalamityReport {
  final String id;
  final String reporterId;
  final String type;
  final String description;
  final DateTime dateReported;
  final String status;

  CalamityReport({
    required this.id,
    required this.reporterId,
    required this.type,
    required this.description,
    required this.dateReported,
    required this.status,
  });

  factory CalamityReport.fromJson(Map<String, dynamic> json) {
    return CalamityReport(
      id: json['id'],
      reporterId: json['farmer_id'],
      type: json['type'],
      description: json['description'],
      dateReported: DateTime.parse(json['occurred_on']),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farmer_id': reporterId,
      'type': type,
      'description': description,
      'occurred_on': dateReported.toIso8601String(),
      'status': status,
    };
  }
}
