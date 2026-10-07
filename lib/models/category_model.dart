class CategoryModel {
  final int id;
  final String name;
  final String icon;
  final String? description;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Category',
      icon: json['icon'] ?? 'category',
      description: json['description'],
    );
  }
}
