import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:invesq_practical/core/constants/api_constants.dart';
import 'package:invesq_practical/core/constants/app_constants.dart';
import 'package:invesq_practical/core/utils/secure_storage_service.dart';
import 'package:invesq_practical/features/auth/data/models/user_model.dart';

class AuthRepository {
  final _storage = SecureStorageService();

  Future<LoginResponse> login(String email, String password) async {
    try {
      final url = ApiConstants.login;
      final body = {'email': email, 'password': password};

      // Log request
      developer.log(
        '🚀 API Request - Login',
        name: 'AuthRepository',
        error: 'POST $url\nBody: ${jsonEncode(body)}',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.headers(),
        body: jsonEncode(body),
      );

      // Log response
      developer.log(
        '✅ API Response - Login',
        name: 'AuthRepository',
        error: 'Status: ${response.statusCode}\nBody: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);

        // Store token and user data
        await _storage.write(AppConstants.tokenKey, loginResponse.token);
        await _storage.write(
          AppConstants.userDataKey,
          jsonEncode(loginResponse.user.toJson()),
        );

        return loginResponse;
      } else {
        final error = jsonDecode(response.body);
        developer.log(
          '❌ API Error - Login',
          name: 'AuthRepository',
          error: 'Status: ${response.statusCode}\nError: ${error['message']}',
        );
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      developer.log(
        '💥 API Exception - Login',
        name: 'AuthRepository',
        error: e.toString(),
      );
      throw Exception('Failed to login: ${e.toString()}');
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(AppConstants.tokenKey);
  }

  Future<UserModel?> getUserData() async {
    final userData = await _storage.read(AppConstants.userDataKey);
    if (userData != null) {
      return UserModel.fromJson(jsonDecode(userData));
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
