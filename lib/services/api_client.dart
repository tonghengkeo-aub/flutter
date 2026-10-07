import '../models/user_model.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8080/api';
  
  static String? authToken;
  static UserModel? currentUser;

  static Map<String, String> defaultHeaders({bool requiresAuth = true, bool isJson = true}) {
    final Map<String, String> h = {};
    if (isJson) {
      h['Content-Type'] = 'application/json';
    }
    if (requiresAuth && authToken != null && authToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $authToken';
    }
    return h;
  }
}
