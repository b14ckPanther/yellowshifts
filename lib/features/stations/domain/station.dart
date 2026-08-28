/// Station domain model representing a physical operational station/branch.
class Station {
  final String id;
  final String name;
  final String code;
  final String timezone;
  final String locale;
  final int weekStart; // 0 = Sunday, 1 = Monday
  final bool isActive;
  final String identityVerificationMode;
  final int lateGraceMinutes;
  final int checkInEarlyMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Station({
    required this.id,
    required this.name,
    required this.code,
    this.timezone = 'Asia/Jerusalem',
    this.locale = 'he',
    this.weekStart = 0,
    this.isActive = true,
    this.identityVerificationMode = 'DISABLED',
    this.lateGraceMinutes = 5,
    this.checkInEarlyMinutes = 15,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String? ?? json['station_code'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Jerusalem',
      locale: json['locale'] as String? ?? 'he',
      weekStart: json['week_start'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      identityVerificationMode:
          json['identity_verification_mode'] as String? ?? 'DISABLED',
      lateGraceMinutes: json['late_grace_minutes'] as int? ?? 5,
      checkInEarlyMinutes: json['check_in_early_minutes'] as int? ?? 15,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'timezone': timezone,
      'locale': locale,
      'week_start': weekStart,
      'is_active': isActive,
      'identity_verification_mode': identityVerificationMode,
      'late_grace_minutes': lateGraceMinutes,
      'check_in_early_minutes': checkInEarlyMinutes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Station copyWith({
    String? id,
    String? name,
    String? code,
    String? timezone,
    String? locale,
    int? weekStart,
    bool? isActive,
    String? identityVerificationMode,
    int? lateGraceMinutes,
    int? checkInEarlyMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      weekStart: weekStart ?? this.weekStart,
      isActive: isActive ?? this.isActive,
      identityVerificationMode:
          identityVerificationMode ?? this.identityVerificationMode,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      checkInEarlyMinutes: checkInEarlyMinutes ?? this.checkInEarlyMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
