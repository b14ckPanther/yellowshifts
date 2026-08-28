class PlatformStationManager {
  final String membershipId;
  final String stationId;
  final String userId;
  final String role;
  final String status;
  final String? employeeCode;
  final DateTime joinedAt;
  final DateTime updatedAt;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;

  const PlatformStationManager({
    required this.membershipId,
    required this.stationId,
    required this.userId,
    required this.role,
    required this.status,
    this.employeeCode,
    required this.joinedAt,
    required this.updatedAt,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isActive => status == 'ACTIVE';

  factory PlatformStationManager.fromJson(Map<String, dynamic> json) {
    return PlatformStationManager(
      membershipId: json['membership_id'] as String,
      stationId: json['station_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'ADMIN',
      status: json['status'] as String? ?? 'ACTIVE',
      employeeCode: json['employee_code'] as String?,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}
