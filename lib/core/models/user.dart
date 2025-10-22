class AppUser {
  final int id;
  final String name;
  final String email;
  final String role; // 'admin' | 'staff'

  AppUser({required this.id, required this.name, required this.email, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    name: j['name'] ?? '',
    email: j['email'] ?? '',
    role: j['role'] ?? 'staff',
  );

  bool get isAdmin => role == 'admin';
}
