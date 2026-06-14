import 'package:pasteleria_180_flutter/core/enums/user_role.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;

  AppUser(
      {required this.id,
      required this.name,
      required this.email,
      required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: UserRoleX.fromString(j['role'] ?? 'guest'),
      );

  bool get isAdmin => role == UserRole.admin;
}
