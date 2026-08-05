class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';
}
