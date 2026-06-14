enum UserRole { admin, staff, guest }

extension UserRoleX on UserRole {
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.guest;
    }
  }
}
