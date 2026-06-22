class InspectionReportModel {
  final String id;
  final String userId;
  final String itemNumber;
  final String photoPath;
  final String defectType;
  final String defectCode;
  final String location;
  final String inspectorComments;
  final String impactCategory;
  final DateTime timestamp;
  final bool isSynced;

  InspectionReportModel({
    required this.id,
    required this.userId,
    required this.itemNumber,
    required this.photoPath,
    required this.defectType,
    required this.defectCode,
    required this.location,
    required this.inspectorComments,
    required this.impactCategory,
    required this.timestamp,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'item_number': itemNumber,
      'photo_path': photoPath,
      'defect_type': defectType,
      'defect_code': defectCode,
      'location': location,
      'inspector_comments': inspectorComments,
      'impact_category': impactCategory,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory InspectionReportModel.fromMap(Map<String, dynamic> map) {
    return InspectionReportModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      itemNumber: map['item_number'] as String,
      photoPath: map['photo_path'] as String,
      defectType: map['defect_type'] as String,
      defectCode: map['defect_code'] as String,
      location: map['location'] as String,
      inspectorComments: map['inspector_comments'] as String,
      impactCategory: map['impact_category'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  InspectionReportModel copyWith({
    String? id,
    String? userId,
    String? itemNumber,
    String? photoPath,
    String? defectType,
    String? defectCode,
    String? location,
    String? inspectorComments,
    String? impactCategory,
    DateTime? timestamp,
    bool? isSynced,
  }) {
    return InspectionReportModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemNumber: itemNumber ?? this.itemNumber,
      photoPath: photoPath ?? this.photoPath,
      defectType: defectType ?? this.defectType,
      defectCode: defectCode ?? this.defectCode,
      location: location ?? this.location,
      inspectorComments: inspectorComments ?? this.inspectorComments,
      impactCategory: impactCategory ?? this.impactCategory,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
