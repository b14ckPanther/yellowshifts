import 'package:flutter/foundation.dart';

/// Implements standard Semantic Versioning (SemVer 2.0.0) parser and comparator.
/// Eliminates naive lexicographical comparison bugs (e.g. "1.9.0" vs "1.10.0").
@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? buildMetadata;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.buildMetadata,
  });

  /// Parse a semantic version string.
  /// Falls back to 0.0.0 if string is null, empty, or unparseable.
  factory SemanticVersion.parse(String? versionString) {
    if (versionString == null || versionString.trim().isEmpty) {
      return const SemanticVersion(major: 0, minor: 0, patch: 0);
    }

    final cleanStr = versionString.trim().replaceFirst(RegExp(r'^[vV]'), '');

    // Split build metadata (+...)
    String coreAndPre = cleanStr;
    String? build;
    final buildIdx = cleanStr.indexOf('+');
    if (buildIdx != -1) {
      coreAndPre = cleanStr.substring(0, buildIdx);
      build = cleanStr.substring(buildIdx + 1);
    }

    // Split pre-release (-...)
    String core = coreAndPre;
    String? pre;
    final preIdx = coreAndPre.indexOf('-');
    if (preIdx != -1) {
      core = coreAndPre.substring(0, preIdx);
      pre = coreAndPre.substring(preIdx + 1);
    }

    final parts = core.split('.');
    final major = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0;
    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final patch = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: pre,
      buildMetadata: build,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }

    // Pre-release versions have lower precedence than normal versions
    if (preRelease == null && other.preRelease != null) {
      return 1;
    }
    if (preRelease != null && other.preRelease == null) {
      return -1;
    }
    if (preRelease != null && other.preRelease != null) {
      return preRelease!.compareTo(other.preRelease!);
    }

    return 0;
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;
  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          preRelease == other.preRelease;

  @override
  int get hashCode =>
      major.hashCode ^ minor.hashCode ^ patch.hashCode ^ preRelease.hashCode;

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (preRelease != null) buffer.write('-$preRelease');
    if (buildMetadata != null) buffer.write('+$buildMetadata');
    return buffer.toString();
  }
}
