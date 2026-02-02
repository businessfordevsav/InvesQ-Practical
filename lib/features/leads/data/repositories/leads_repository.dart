import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:invesq_practical/core/constants/api_constants.dart';
import 'package:invesq_practical/features/leads/data/models/lead_model.dart';

class LeadsRepository {
  Future<LeadsResponse> getLeads({
    required String token,
    int page = 1,
    int perPage = 50,
    String sortBy = 'lead_source_id',
    String sortDirection = 'desc',
  }) async {
    try {
      final uri = Uri.parse(ApiConstants.leads).replace(
        queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
          'sortBy': sortBy,
          'sortDirection': sortDirection,
        },
      );

      // Log request
      developer.log(
        '🚀 API Request - Get Leads',
        name: 'LeadsRepository',
        error: 'GET $uri\nPage: $page, PerPage: $perPage',
      );

      final response = await http.get(
        uri,
        headers: ApiConstants.headers(token: token),
      );

      // Log response
      developer.log(
        '✅ API Response - Get Leads',
        name: 'LeadsRepository',
        error:
            'Status: ${response.statusCode}\nData Length: ${response.body.length} bytes',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LeadsResponse.fromJson(data);
      } else {
        developer.log(
          '❌ API Error - Get Leads',
          name: 'LeadsRepository',
          error: 'Status: ${response.statusCode}\nBody: ${response.body}',
        );
        throw Exception('Failed to load leads');
      }
    } catch (e) {
      developer.log(
        '💥 API Exception - Get Leads',
        name: 'LeadsRepository',
        error: e.toString(),
      );
      throw Exception('Failed to fetch leads: ${e.toString()}');
    }
  }
}
