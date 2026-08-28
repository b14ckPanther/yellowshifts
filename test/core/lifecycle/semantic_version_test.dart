import 'package:flutter_test/flutter_test.dart';
import 'package:yellowshifts/core/lifecycle/semantic_version.dart';

void main() {
  group('SemanticVersion Parser & Comparison Tests', () {
    test('Correctly parses basic SemVer strings', () {
      final v1 = SemanticVersion.parse('1.0.0');
      expect(v1.major, 1);
      expect(v1.minor, 0);
      expect(v1.patch, 0);
      expect(v1.preRelease, isNull);

      final v2 = SemanticVersion.parse('v2.14.8');
      expect(v2.major, 2);
      expect(v2.minor, 14);
      expect(v2.patch, 8);
    });

    test('Correctly parses pre-release and build metadata', () {
      final v = SemanticVersion.parse('1.2.3-beta.1+build.42');
      expect(v.major, 1);
      expect(v.minor, 2);
      expect(v.patch, 3);
      expect(v.preRelease, 'beta.1');
      expect(v.buildMetadata, 'build.42');
    });

    test('Handles null, empty and invalid strings safely (fallback to 0.0.0)',
        () {
      expect(SemanticVersion.parse(null),
          const SemanticVersion(major: 0, minor: 0, patch: 0));
      expect(SemanticVersion.parse(''),
          const SemanticVersion(major: 0, minor: 0, patch: 0));
      expect(SemanticVersion.parse('invalid'),
          const SemanticVersion(major: 0, minor: 0, patch: 0));
    });

    test('Accurately compares 1.9.0 vs 1.10.0 (Lexicographical Pitfall)', () {
      final v9 = SemanticVersion.parse('1.9.0');
      final v10 = SemanticVersion.parse('1.10.0');

      expect(v9 < v10, isTrue,
          reason: '1.9.0 must be strictly less than 1.10.0');
      expect(v10 > v9, isTrue);
      expect(v9.compareTo(v10), isNegative);
    });

    test('Accurately compares 1.0.9 vs 1.0.10', () {
      final v9 = SemanticVersion.parse('1.0.9');
      final v10 = SemanticVersion.parse('1.0.10');

      expect(v9 < v10, isTrue);
      expect(v10 > v9, isTrue);
    });

    test('Accurately compares 2.0.0 vs 1.99.99', () {
      final v2 = SemanticVersion.parse('2.0.0');
      final v1 = SemanticVersion.parse('1.99.99');

      expect(v2 > v1, isTrue);
      expect(v1 < v2, isTrue);
    });

    test('Pre-release versions have lower precedence than normal releases', () {
      final release = SemanticVersion.parse('1.0.0');
      final preRelease = SemanticVersion.parse('1.0.0-rc.1');

      expect(preRelease < release, isTrue);
      expect(release > preRelease, isTrue);
    });

    test('Equality and toString serialization', () {
      final vA = SemanticVersion.parse('1.5.2');
      const vB = SemanticVersion(major: 1, minor: 5, patch: 2);

      expect(vA, equals(vB));
      expect(vA.toString(), '1.5.2');
    });
  });
}
