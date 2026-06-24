class SessionModel {
  final String id;
  final String userId;
  final String sessionName;
  final String projectName;
  final String siteLocation;
  final DateTime inspectionDate;
  final DateTime createdAt;

  SessionModel({
    required this.id,
    required this.userId,
    required this.sessionName,
    required this.projectName,
    required this.siteLocation,
    required this.inspectionDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_name': sessionName,
      'project_name': projectName,
      'site_location': siteLocation,
      'inspection_date': inspectionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      sessionName: map['session_name'] as String,
      projectName: map['project_name'] as String,
      siteLocation: map['site_location'] as String,
      inspectionDate: DateTime.parse(map['inspection_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SessionModel copyWith({
    String? id,
    String? userId,
    String? sessionName,
    String? projectName,
    String? siteLocation,
    DateTime? inspectionDate,
    DateTime? createdAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionName: sessionName ?? this.sessionName,
      projectName: projectName ?? this.projectName,
      siteLocation: siteLocation ?? this.siteLocation,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
