import 'dart:convert';

class InspectionReportModel {
  final String id;
  final String userId;
  final String sessionId;
  final String itemNumber;
  final List<String> photoPaths;
  final String defectType;
  final String defectCode;
  final String location;
  final String inspectorComments;
  final String impactCategory;
  final String status;
  final String refNo;
  final String section;
  final bool scopeInternal;
  final bool scopeExternal;
  final bool scopeME;
  final bool scopePublicFacilities;
  final List<String> selectedDefectCodes;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime timestamp;
  final bool isSynced;

  InspectionReportModel({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.itemNumber,
    required this.photoPaths,
    required this.defectType,
    required this.defectCode,
    required this.location,
    required this.inspectorComments,
    required this.impactCategory,
    required this.status,
    this.refNo = '',
    this.section = '',
    this.scopeInternal = false,
    this.scopeExternal = false,
    this.scopeME = false,
    this.scopePublicFacilities = false,
    this.selectedDefectCodes = const [],
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
      'session_id': sessionId,
      'item_number': itemNumber,
      'photo_path': primaryPhotoPath,
      'photo_paths': jsonEncode(photoPaths),
      'defect_type': defectType,
      'defect_code': defectCode,
      'location': location,
      'inspector_comments': inspectorComments,
      'impact_category': impactCategory,
      'status': status,
      'ref_no': refNo,
      'section': section,
      'scope_internal': scopeInternal ? 1 : 0,
      'scope_external': scopeExternal ? 1 : 0,
      'scope_me': scopeME ? 1 : 0,
      'scope_public_facilities': scopePublicFacilities ? 1 : 0,
      'selected_defect_codes': jsonEncode(selectedDefectCodes),
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

    List<String> parsedDefectCodes = [];
    final rawDefectCodes = map['selected_defect_codes'];
    if (rawDefectCodes is String && rawDefectCodes.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDefectCodes);
        if (decoded is List) {
          parsedDefectCodes = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return InspectionReportModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionId: map['session_id'] as String? ?? '',
      itemNumber: map['item_number'] as String,
      photoPaths: parsedPhotoPaths,
      defectType: (map['defect_type'] ?? 'General') as String,
      defectCode: (map['defect_code'] ?? 'ND0') as String,
      location: (map['location'] ?? '') as String,
      inspectorComments: (map['inspector_comments'] ?? '') as String,
      impactCategory: (map['impact_category'] ?? 'Minor') as String,
      status: (map['status'] ?? 'No Defect') as String,
      refNo: (map['ref_no'] ?? '') as String,
      section: (map['section'] ?? '') as String,
      scopeInternal: (map['scope_internal'] ?? 0) == 1,
      scopeExternal: (map['scope_external'] ?? 0) == 1,
      scopeME: (map['scope_me'] ?? 0) == 1,
      scopePublicFacilities: (map['scope_public_facilities'] ?? 0) == 1,
      selectedDefectCodes: parsedDefectCodes,
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
    String? sessionId,
    String? itemNumber,
    List<String>? photoPaths,
    String? defectType,
    String? defectCode,
    String? location,
    String? inspectorComments,
    String? impactCategory,
    String? status,
    String? refNo,
    String? section,
    bool? scopeInternal,
    bool? scopeExternal,
    bool? scopeME,
    bool? scopePublicFacilities,
    List<String>? selectedDefectCodes,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
    bool? isSynced,
  }) {
    return InspectionReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      itemNumber: itemNumber ?? this.itemNumber,
      photoPaths: photoPaths ?? this.photoPaths,
      defectType: defectType ?? this.defectType,
      defectCode: defectCode ?? this.defectCode,
      location: location ?? this.location,
      inspectorComments: inspectorComments ?? this.inspectorComments,
      impactCategory: impactCategory ?? this.impactCategory,
      status: status ?? this.status,
      refNo: refNo ?? this.refNo,
      section: section ?? this.section,
      scopeInternal: scopeInternal ?? this.scopeInternal,
      scopeExternal: scopeExternal ?? this.scopeExternal,
      scopeME: scopeME ?? this.scopeME,
      scopePublicFacilities:
          scopePublicFacilities ?? this.scopePublicFacilities,
      selectedDefectCodes: selectedDefectCodes ?? this.selectedDefectCodes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
