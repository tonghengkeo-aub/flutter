class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String token;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'CUSTOMER',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'token': token,
    };
  }
}
