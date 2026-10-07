import 'package:flutter/foundation.dart';

class RoomModel {
  static String _safeUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('data:image')) return raw;
    if (raw.contains('wsrv.nl')) return raw;
    if (kIsWeb || raw.contains('pinimg.com')) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return 'https://wsrv.nl/?url=${Uri.encodeComponent(raw)}';
      }
    }
    return raw;
  }

  final int id;
  final int hotelId;
  final String roomNumber;
  final String type;
  final double priceUsd;
  final double priceKhr;
  final int maxGuests;
  final String bedType;
  final String description;
  final String images;
  final String status;

  RoomModel({
    required this.id,
    required this.hotelId,
    required this.roomNumber,
    required this.type,
    required this.priceUsd,
    required this.priceKhr,
    required this.maxGuests,
    required this.bedType,
    required this.description,
    required this.images,
    required this.status,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    double usd = json['priceUsd'] != null ? (double.tryParse(json['priceUsd'].toString()) ?? 50.0) : 50.0;
    double khr = json['priceKhr'] != null ? (double.tryParse(json['priceKhr'].toString()) ?? (usd * 4100)) : (usd * 4100);

    return RoomModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      hotelId: json['hotel'] != null && json['hotel']['id'] != null 
          ? json['hotel']['id'] 
          : (json['hotelId'] ?? 0),
      roomNumber: json['roomNumber'] ?? '',
      type: json['type'] ?? 'DOUBLE',
      priceUsd: usd,
      priceKhr: khr,
      maxGuests: json['maxGuests'] ?? 2,
      bedType: json['bedType'] ?? '1 King Bed',
      description: json['description'] ?? '',
      images: json['images'] ?? 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600',
      status: json['status'] ?? 'AVAILABLE',
    );
  }

  String get firstImageUrl {
    if (images.isEmpty) return 'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=600';
    final cleaned = images
        .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
        .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
    final list = cleaned
        .split(RegExp(r'[\r\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))
        .map(_safeUrl)
        .toList();
    return list.isNotEmpty ? list.first : _safeUrl(images);
  }

  List<String> get allImages {
    if (images.isEmpty) return [];
    final cleaned = images
        .replaceAllMapped(RegExp(r'(https?://)', caseSensitive: false), (m) => '\n${m[1]}')
        .replaceAllMapped(RegExp(r'(data:image/)', caseSensitive: false), (m) => '\n${m[1]}');
    return cleaned
        .split(RegExp(r'[\r\n,;\s]+'))
        .map((s) => s.trim())
        .where((s) => s.startsWith('http://') || s.startsWith('https://') || s.startsWith('data:image/'))
        .map(_safeUrl)
        .toList();
  }
}
