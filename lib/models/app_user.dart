class AppUser {
  const AppUser({
    required this.username,
    required this.name,
    required this.phone,
    required this.carNumber,
    this.createdAt,
  });

  final String username;
  final String name;
  final String phone;
  final String carNumber;
  final String? createdAt;

  Map<String, dynamic> toJson({required String passwordHash}) {
    return {
      'username': username,
      'name': name,
      'phone': phone,
      'carNumber': carNumber,
      'passwordHash': passwordHash,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<dynamic, dynamic> json) {
    return AppUser(
      username: '${json['username'] ?? ''}',
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      carNumber: '${json['carNumber'] ?? ''}',
      createdAt: json['createdAt']?.toString(),
    );
  }
}
