class ReportModel {
  final String id;
  final String userId;
  final String reportName;
  final String site;
  final String sector;
  final String siteLocation;
  final String inspector;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.reportName,
    required this.site,
    required this.sector,
    required this.siteLocation,
    required this.inspector,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'report_name': reportName,
      'site': site,
      'sector': sector,
      'site_location': siteLocation,
      'inspector': inspector,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      reportName: (map['report_name'] ?? '') as String,
      site: (map['site'] ?? '') as String,
      sector: (map['sector'] ?? '') as String,
      siteLocation: (map['site_location'] ?? '') as String,
      inspector: (map['inspector'] ?? '') as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ReportModel copyWith({
    String? id,
    String? userId,
    String? reportName,
    String? site,
    String? sector,
    String? siteLocation,
    String? inspector,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reportName: reportName ?? this.reportName,
      site: site ?? this.site,
      sector: sector ?? this.sector,
      siteLocation: siteLocation ?? this.siteLocation,
      inspector: inspector ?? this.inspector,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
