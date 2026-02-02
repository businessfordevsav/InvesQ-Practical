import 'package:flutter/material.dart';
import 'package:invesq_practical/features/leads/data/models/lead_model.dart';
import 'package:invesq_practical/features/leads/data/repositories/leads_repository.dart';

enum LeadsState { initial, loading, loaded, loadingMore, error }

class LeadsProvider with ChangeNotifier {
  final LeadsRepository _leadsRepository = LeadsRepository();

  LeadsState _state = LeadsState.initial;
  final List<LeadModel> _leads = [];
  List<LeadModel> _filteredLeads = [];
  String _searchQuery = '';
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  String? _errorMessage;

  LeadsState get state => _state;
  List<LeadModel> get leads => _filteredLeads;
  int get total => _total;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _currentPage < _lastPage;
  String get searchQuery => _searchQuery;

  Future<void> fetchLeads(String token, {bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _leads.clear();
      _filteredLeads.clear();
    }

    try {
      _state = refresh ? LeadsState.loading : LeadsState.loadingMore;
      _errorMessage = null;
      notifyListeners();

      final response = await _leadsRepository.getLeads(
        token: token,
        page: _currentPage,
      );

      _leads.addAll(response.leads);
      _lastPage = response.lastPage;
      _total = response.total;
      _currentPage++;

      _applySearch();
      _state = LeadsState.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _state = LeadsState.error;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applySearch();
    notifyListeners();
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredLeads = List.from(_leads);
    } else {
      _filteredLeads = _leads.where((lead) {
        final name = lead.fullName.toLowerCase();
        final email = (lead.email ?? '').toLowerCase();
        final company = (lead.company ?? '').toLowerCase();
        final phone = (lead.phone ?? '').toLowerCase();

        return name.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            company.contains(_searchQuery) ||
            phone.contains(_searchQuery);
      }).toList();
    }
  }

  void reset() {
    _leads.clear();
    _filteredLeads.clear();
    _currentPage = 1;
    _lastPage = 1;
    _total = 0;
    _searchQuery = '';
    _state = LeadsState.initial;
    notifyListeners();
  }
}
