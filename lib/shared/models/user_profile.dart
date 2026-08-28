/// User Profile domain model representing 1:1 mapping with auth.users.
class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String preferredLocale;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.preferredLocale = 'he',
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName {
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    if (cleanFirst.isEmpty && cleanLast.isEmpty) return 'User';
    if (cleanFirst.isEmpty) return cleanLast;
    if (cleanLast.isEmpty) return cleanFirst;
    return '$cleanFirst $cleanLast';
  }

  String get initials {
    final cleanFirst = firstName.trim();
    final cleanLast = lastName.trim();
    if (cleanFirst.isNotEmpty && cleanLast.isNotEmpty) {
      return '${cleanFirst[0]}${cleanLast[0]}'.toUpperCase();
    } else if (cleanFirst.isNotEmpty) {
      return cleanFirst
          .substring(0, cleanFirst.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return 'YS';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String?,
      preferredLocale: json['preferred_locale'] as String? ?? 'he',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'preferred_locale': preferredLocale,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? preferredLocale,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
