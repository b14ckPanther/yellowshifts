import 'station.dart';

enum StationRole {
  admin('ADMIN'),
  shiftManager('SHIFT_MANAGER'),
  employee('EMPLOYEE');

  final String value;
  const StationRole(this.value);

  static StationRole fromString(String? roleStr) {
    switch (roleStr?.toUpperCase()) {
      case 'ADMIN':
        return StationRole.admin;
      case 'SHIFT_MANAGER':
        return StationRole.shiftManager;
      case 'EMPLOYEE':
      default:
        return StationRole.employee;
    }
  }

  bool get isAdmin => this == StationRole.admin;
  bool get isShiftManager => this == StationRole.shiftManager;
  bool get isEmployee => this == StationRole.employee;
  bool get isManagerOrAdmin =>
      this == StationRole.admin || this == StationRole.shiftManager;
}

enum MembershipStatus {
  active('ACTIVE'),
  inactive('INACTIVE'),
  suspended('SUSPENDED');

  final String value;
  const MembershipStatus(this.value);

  static MembershipStatus fromString(String? statusStr) {
    switch (statusStr?.toUpperCase()) {
      case 'ACTIVE':
        return MembershipStatus.active;
      case 'INACTIVE':
        return MembershipStatus.inactive;
      case 'SUSPENDED':
        return MembershipStatus.suspended;
      default:
        return MembershipStatus.active;
    }
  }

  bool get isActive => this == MembershipStatus.active;
  bool get isInactive => this == MembershipStatus.inactive;
  bool get isSuspended => this == MembershipStatus.suspended;
}

/// Domain model representing a user's membership within a specific station.
class StationMembership {
  final String id;
  final String stationId;
  final String userId;
  final StationRole role;
  final MembershipStatus status;
  final String? employeeCode;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Station? station;

  const StationMembership({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.role,
    required this.status,
    this.employeeCode,
    required this.joinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.station,
  })  : createdAt = createdAt ?? joinedAt,
        updatedAt = updatedAt ?? joinedAt;

  factory StationMembership.fromJson(Map<String, dynamic> json) {
    Station? embeddedStation;
    if (json['stations'] != null && json['stations'] is Map<String, dynamic>) {
      embeddedStation =
          Station.fromJson(json['stations'] as Map<String, dynamic>);
    }

    return StationMembership(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      userId: json['user_id'] as String,
      role: StationRole.fromString(json['role'] as String?),
      status: MembershipStatus.fromString(json['status'] as String?),
      employeeCode: json['employee_code'] as String?,
      joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      station: embeddedStation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'user_id': userId,
      'role': role.value,
      'status': status.value,
      'employee_code': employeeCode,
      'joined_at': joinedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (station != null) 'stations': station!.toJson(),
    };
  }

  StationMembership copyWith({
    String? id,
    String? stationId,
    String? userId,
    StationRole? role,
    MembershipStatus? status,
    String? employeeCode,
    DateTime? joinedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Station? station,
  }) {
    return StationMembership(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      employeeCode: employeeCode ?? this.employeeCode,
      joinedAt: joinedAt ?? this.joinedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      station: station ?? this.station,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationMembership &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          stationId == other.stationId &&
          userId == other.userId &&
          role == other.role &&
          status == other.status &&
          employeeCode == other.employeeCode;

  @override
  int get hashCode =>
      id.hashCode ^
      stationId.hashCode ^
      userId.hashCode ^
      role.hashCode ^
      status.hashCode ^
      employeeCode.hashCode;
}
