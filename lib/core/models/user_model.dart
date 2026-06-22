class UserModel {
  final String id;
  final String name;
  final String username;
  final String inspectorId;
  final String passwordHash;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.inspectorId,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'inspector_id': inspectorId,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      username: map['username'] as String,
      inspectorId: map['inspector_id'] as String,
      passwordHash: map['password_hash'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? inspectorId,
    String? passwordHash,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      inspectorId: inspectorId ?? this.inspectorId,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
