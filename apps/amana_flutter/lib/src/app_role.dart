enum AppRole {
  customer('customer', 'عميل'),
  provider('provider', 'مقدم خدمة'),
  admin('admin', 'إدارة');

  const AppRole(this.value, this.arabicLabel);

  final String value;
  final String arabicLabel;

  static AppRole? fromValue(String value) {
    for (final role in values) {
      if (role.value == value.toLowerCase()) return role;
    }
    return null;
  }
}

/// A build-time role is useful for producing separate branded targets from the
/// same codebase. In production, [SessionRoleSource] must read the verified
/// role from the authenticated backend session/JWT, not from local input.
abstract interface class SessionRoleSource {
  AppRole? get authenticatedRole;
}

class ScaffoldSessionRoleSource implements SessionRoleSource {
  const ScaffoldSessionRoleSource();

  @override
  AppRole? get authenticatedRole {
    const configured = String.fromEnvironment('AMANA_ROLE');
    return AppRole.fromValue(configured);
  }
}
