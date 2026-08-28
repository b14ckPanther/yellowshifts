import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/shared/models/user_profile.dart';
import 'package:yellowshifts/features/stations/domain/station.dart';
import 'package:yellowshifts/features/stations/domain/station_membership.dart';

void main() {
  group('Domain Models & Serialization', () {
    test('UserProfile serialization, fullName and initials derivation', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '11111111-1111-1111-1111-111111111111',
        firstName: 'David',
        lastName: 'Cohen',
        phone: '+972501234567',
        preferredLocale: 'he',
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.fullName, 'David Cohen');
      expect(profile.initials, 'DC');

      final json = profile.toJson();
      expect(json['first_name'], 'David');
      expect(json['last_name'], 'Cohen');

      final deserialized = UserProfile.fromJson(json);
      expect(deserialized.id, profile.id);
      expect(deserialized.firstName, 'David');
      expect(deserialized.lastName, 'Cohen');
      expect(deserialized.phone, '+972501234567');
    });

    test('Station model serialization', () {
      final now = DateTime.now();
      final station = Station(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        name: 'Galil Central Hub',
        code: 'YS-GAL-01',
        timezone: 'Asia/Jerusalem',
        locale: 'he',
        weekStart: 0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = station.toJson();
      expect(json['name'], 'Galil Central Hub');
      expect(json['code'], 'YS-GAL-01');

      final deserialized = Station.fromJson(json);
      expect(deserialized.name, 'Galil Central Hub');
      expect(deserialized.code, 'YS-GAL-01');
      expect(deserialized.isActive, true);
    });

    test('StationMembership multi-station role serialization and enums', () {
      final now = DateTime.now();
      final membership = StationMembership(
        id: 'mmmmmmmm-mmmm-mmmm-mmmm-mmmmmmmmmmmm',
        stationId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        userId: '11111111-1111-1111-1111-111111111111',
        role: StationRole.admin,
        status: MembershipStatus.active,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(membership.role.isAdmin, true);
      expect(membership.role.isShiftManager, false);
      expect(membership.status.isActive, true);

      final json = membership.toJson();
      expect(json['role'], 'ADMIN');
      expect(json['status'], 'ACTIVE');

      final deserialized = StationMembership.fromJson(json);
      expect(deserialized.role, StationRole.admin);
      expect(deserialized.status, MembershipStatus.active);
    });
  });
}
