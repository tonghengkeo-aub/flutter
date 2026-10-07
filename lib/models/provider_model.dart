class ProviderModel {
  final int id;
  final String name;
  final String title;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final double rating;
  final String workingHours;
  final bool isAvailable;

  ProviderModel({
    required this.id,
    required this.name,
    required this.title,
    this.phone,
    this.email,
    this.avatarUrl,
    required this.rating,
    required this.workingHours,
    required this.isAvailable,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Specialist',
      title: json['title'] ?? 'Staff',
      phone: json['phone'],
      email: json['email'],
      avatarUrl: json['avatarUrl'] ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
      rating: json['rating'] != null ? (double.tryParse(json['rating'].toString()) ?? 4.9) : 4.9,
      workingHours: json['workingHours'] ?? '08:00 AM - 07:00 PM',
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}
