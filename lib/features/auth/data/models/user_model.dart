class UserModel {
  final int id;
  final String name;
  final String email;
  final String? avatar;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle both 'contact' structure from API and stored 'user' structure
    final data = json.containsKey('firstname') ? json : json['contact'] ?? json;

    return UserModel(
      id: data['id'] as int,
      name: '${data['firstname'] ?? ''} ${data['lastname'] ?? ''}'.trim(),
      email: data['email'] as String,
      avatar: data['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'avatar': avatar};
  }
}

class LoginResponse {
  final String token;
  final UserModel user;

  LoginResponse({required this.token, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Extract data from nested structure
    final data = json['data'] as Map<String, dynamic>;

    return LoginResponse(
      token: data['access_token'] as String,
      user: UserModel.fromJson(data),
    );
  }
}
