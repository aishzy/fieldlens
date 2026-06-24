import 'dart:convert';

class InspectionReportModel {
  final String id;
  final String userId;
  final String itemNumber;
  final List<String> photoPaths;
  final String defectType;
  final String defectCode;
  final String location;
  final String inspectorComments;
  final String impactCategory;
  final String status;
  final String projectName;
  final String projectCode;
  final String projectSiteLocation;
  final String reportNumber;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime timestamp;
  final bool isSynced;

  InspectionReportModel({
    required this.id,
    required this.userId,
    required this.itemNumber,
    required this.photoPaths,
    required this.defectType,
    required this.defectCode,
    required this.location,
    required this.inspectorComments,
    required this.impactCategory,
    required this.status,
    required this.projectName,
    required this.projectCode,
    required this.projectSiteLocation,
    required this.reportNumber,
    this.latitude,
    this.longitude,
    this.address,
    required this.timestamp,
    this.isSynced = false,
  });

  String get primaryPhotoPath => photoPaths.isNotEmpty ? photoPaths.first : '';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'item_number': itemNumber,
      'photo_path': primaryPhotoPath,
      'photo_paths': jsonEncode(photoPaths),
      'defect_type': defectType,
      'defect_code': defectCode,
      'location': location,
      'inspector_comments': inspectorComments,
      'impact_category': impactCategory,
      'status': status,
      'project_name': projectName,
      'project_code': projectCode,
      'project_site_location': projectSiteLocation,
      'report_number': reportNumber,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory InspectionReportModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawPhotoPaths = map['photo_paths'];
    List<String> parsedPhotoPaths = [];
    if (rawPhotoPaths is String && rawPhotoPaths.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPhotoPaths);
        if (decoded is List) {
          parsedPhotoPaths = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedPhotoPaths = [];
      }
    }

    if (parsedPhotoPaths.isEmpty && map['photo_path'] is String) {
      final legacyPath = map['photo_path'] as String;
      if (legacyPath.isNotEmpty) {
        parsedPhotoPaths = [legacyPath];
      }
    }

    return InspectionReportModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      itemNumber: map['item_number'] as String,
      photoPaths: parsedPhotoPaths,
      defectType: (map['defect_type'] ?? 'General') as String,
      defectCode: (map['defect_code'] ?? 'ND0') as String,
      location: (map['location'] ?? '') as String,
      inspectorComments: (map['inspector_comments'] ?? '') as String,
      impactCategory: (map['impact_category'] ?? 'Minor') as String,
      status: (map['status'] ?? 'No Defect') as String,
      projectName: (map['project_name'] ?? '') as String,
      projectCode: (map['project_code'] ?? '') as String,
      projectSiteLocation: (map['project_site_location'] ?? '') as String,
      reportNumber: (map['report_number'] ?? '') as String,
      latitude:
          map['latitude'] is num ? (map['latitude'] as num).toDouble() : null,
      longitude:
          map['longitude'] is num ? (map['longitude'] as num).toDouble() : null,
      address: map['address'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  InspectionReportModel copyWith({
    String? id,
    String? userId,
    String? itemNumber,
    List<String>? photoPaths,
    String? defectType,
    String? defectCode,
    String? location,
    String? inspectorComments,
    String? impactCategory,
    String? status,
    String? projectName,
    String? projectCode,
    String? projectSiteLocation,
    String? reportNumber,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
    bool? isSynced,
  }) {
    return InspectionReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemNumber: itemNumber ?? this.itemNumber,
      photoPaths: photoPaths ?? this.photoPaths,
      defectType: defectType ?? this.defectType,
      defectCode: defectCode ?? this.defectCode,
      location: location ?? this.location,
      inspectorComments: inspectorComments ?? this.inspectorComments,
      impactCategory: impactCategory ?? this.impactCategory,
      status: status ?? this.status,
      projectName: projectName ?? this.projectName,
      projectCode: projectCode ?? this.projectCode,
      projectSiteLocation: projectSiteLocation ?? this.projectSiteLocation,
      reportNumber: reportNumber ?? this.reportNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
