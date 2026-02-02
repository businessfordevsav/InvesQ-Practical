import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invesq_practical/features/auth/presentation/providers/auth_provider.dart';
import 'package:invesq_practical/features/leads/presentation/providers/leads_provider.dart';
import 'package:invesq_practical/features/leads/data/models/lead_model.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late LeadsProvider _leadsProvider;

  @override
  void initState() {
    super.initState();
    _leadsProvider = LeadsProvider();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLeads();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadLeads() async {
    final token = context.read<AuthProvider>().token;
    if (token != null) {
      await _leadsProvider.fetchLeads(token, refresh: true);
    }
  }

  Future<void> _loadMore() async {
    if (_leadsProvider.state != LeadsState.loadingMore &&
        _leadsProvider.hasMore) {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        await _leadsProvider.fetchLeads(token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _leadsProvider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Leads')),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search leads...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _leadsProvider.search('');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  _leadsProvider.search(value);
                },
              ),
            ),

            // Leads List
            Expanded(
              child: Consumer<LeadsProvider>(
                builder: (context, provider, child) {
                  if (provider.state == LeadsState.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.state == LeadsState.error) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            provider.errorMessage ?? 'An error occurred',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadLeads,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.leads.isEmpty && provider.searchQuery.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No leads found',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  if (provider.leads.isEmpty &&
                      provider.searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No results for "${provider.searchQuery}"',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadLeads,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: provider.leads.length + 1,
                      itemBuilder: (context, index) {
                        if (index == provider.leads.length) {
                          if (provider.state == LeadsState.loadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else if (provider.hasMore) {
                            return const SizedBox(height: 80);
                          } else {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'Loaded ${provider.leads.length} of ${provider.total} leads',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            );
                          }
                        }

                        return _LeadCard(lead: provider.leads[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final LeadModel lead;

  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            lead.fullName.isNotEmpty ? lead.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          lead.fullName.isNotEmpty ? lead.fullName : 'Unnamed Lead',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lead.email != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(lead.email!, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            if (lead.phone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(lead.phone!),
                ],
              ),
            ],
            if (lead.company != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.business_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(lead.company!, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: lead.status != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(lead.status!).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lead.status!,
                  style: TextStyle(
                    color: _getStatusColor(lead.status!),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'contacted':
        return Colors.orange;
      case 'qualified':
        return Colors.green;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
