enum IdentityVerificationMode {
  disabled,
  checkInOnly,
  checkInAndCheckOut;

  static IdentityVerificationMode fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'CHECK_IN_ONLY':
        return IdentityVerificationMode.checkInOnly;
      case 'CHECK_IN_AND_CHECK_OUT':
        return IdentityVerificationMode.checkInAndCheckOut;
      case 'DISABLED':
      default:
        return IdentityVerificationMode.disabled;
    }
  }

  String toDbValue() {
    switch (this) {
      case IdentityVerificationMode.checkInOnly:
        return 'CHECK_IN_ONLY';
      case IdentityVerificationMode.checkInAndCheckOut:
        return 'CHECK_IN_AND_CHECK_OUT';
      case IdentityVerificationMode.disabled:
        return 'DISABLED';
    }
  }

  bool get isRequiredForCheckIn =>
      this == IdentityVerificationMode.checkInOnly ||
      this == IdentityVerificationMode.checkInAndCheckOut;

  bool get isRequiredForCheckOut =>
      this == IdentityVerificationMode.checkInAndCheckOut;
}
