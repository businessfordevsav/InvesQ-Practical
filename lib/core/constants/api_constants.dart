class ApiConstants {
  static const String baseUrl =
      'https://api-invesqcrm.rundfunkbeitragservice.com/api';

  // Auth endpoints
  static const String login = '$baseUrl/login';

  // Leads endpoints
  static const String leads = '$baseUrl/leads';

  // Headers
  static Map<String, String> headers({String? token}) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
