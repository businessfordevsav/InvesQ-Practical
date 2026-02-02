class LeadModel {
  final int id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? company;
  final String? leadSource;
  final String? status;
  final String? createdAt;

  LeadModel({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.company,
    this.leadSource,
    this.status,
    this.createdAt,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory LeadModel.fromJson(Map<String, dynamic> json) {
    return LeadModel(
      id: (json['id'] ?? 0) as int,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
      leadSource: json['lead_source'] as String?,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

class LeadsResponse {
  final List<LeadModel> leads;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;

  LeadsResponse({
    required this.leads,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
  });

  factory LeadsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List;
    return LeadsResponse(
      leads: data.map((item) => LeadModel.fromJson(item)).toList(),
      currentPage: (json['current_page'] ?? 1) as int,
      lastPage: (json['last_page'] ?? 1) as int,
      total: (json['total'] ?? 0) as int,
      perPage: (json['per_page'] ?? 50) as int,
    );
  }

  bool get hasMore => currentPage < lastPage;
}
