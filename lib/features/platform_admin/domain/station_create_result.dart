class StationCreateResult {
  final String stationId;
  final String name;
  final String code;
  final bool idempotent;
  final bool isNewUser;
  final String? email;
  final String? temporaryPassword;

  const StationCreateResult({
    required this.stationId,
    required this.name,
    required this.code,
    required this.idempotent,
    required this.isNewUser,
    this.email,
    this.temporaryPassword,
  });

  factory StationCreateResult.fromJson(Map<String, dynamic> json) {
    return StationCreateResult(
      stationId: json['station_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      idempotent: json['idempotent'] as bool? ?? false,
      isNewUser: json['is_new_user'] as bool? ?? false,
      email: json['email'] as String?,
      temporaryPassword: json['temporary_password'] as String?,
    );
  }
}

class StationManagerAssignmentResult {
  final String membershipId;
  final String userId;
  final bool isNewUser;
  final String? email;
  final String? temporaryPassword;

  const StationManagerAssignmentResult({
    required this.membershipId,
    required this.userId,
    required this.isNewUser,
    this.email,
    this.temporaryPassword,
  });

  factory StationManagerAssignmentResult.fromJson(Map<String, dynamic> json) {
    final assigned = json['assigned'] is Map<String, dynamic>
        ? json['assigned'] as Map<String, dynamic>
        : json;
    return StationManagerAssignmentResult(
      membershipId: assigned['membership_id'] as String? ?? '',
      userId:
          assigned['user_id'] as String? ?? json['user_id'] as String? ?? '',
      isNewUser: json['is_new_user'] as bool? ?? false,
      email: json['email'] as String?,
      temporaryPassword: json['temporary_password'] as String?,
    );
  }
}
