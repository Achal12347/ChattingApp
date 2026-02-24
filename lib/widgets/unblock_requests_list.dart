import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/unblock_request_provider.dart';
import '../models/unblock_request_model.dart';
import '../services/relationship_service.dart';

class UnblockRequestsList extends ConsumerStatefulWidget {
  const UnblockRequestsList({super.key});

  @override
  ConsumerState<UnblockRequestsList> createState() =>
      _UnblockRequestsListState();
}

class _UnblockRequestsListState extends ConsumerState<UnblockRequestsList> {
  final RelationshipService _relationshipService = RelationshipService();
  Map<String, String> _relationships = {};
  bool _isLoadingRelationships = true;

  @override
  void initState() {
    super.initState();
    _loadRelationships();
  }

  Future<void> _loadRelationships() async {
    final unblockRequestsAsync = ref.read(unblockRequestsStreamProvider);
    unblockRequestsAsync.whenData((unblockRequests) async {
      final relationships = <String, String>{};

      for (final request in unblockRequests) {
        final relationship =
            await _relationshipService.getRelationship(request.fromUserId);
        relationships[request.fromUserId] = relationship ?? 'none';
      }

      if (mounted) {
        setState(() {
          _relationships = relationships;
          _isLoadingRelationships = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(UnblockRequestsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadRelationships();
  }

  Map<String, List<UnblockRequestModel>> _categorizeRequests(
      List<UnblockRequestModel> requests) {
    final categorized = <String, List<UnblockRequestModel>>{};

    for (final request in requests) {
      final relationship = _relationships[request.fromUserId] ?? 'none';
      if (!categorized.containsKey(relationship)) {
        categorized[relationship] = [];
      }
      categorized[relationship]!.add(request);
    }

    return categorized;
  }

  String _getRelationshipDisplayName(String relationship) {
    switch (relationship) {
      case 'friend':
        return 'Friends (Limit: 2 requests)';
      case 'best_friend':
        return 'Best Friends (Limit: 4 requests)';
      case 'family':
        return 'Family (Unlimited requests)';
      default:
        return 'Others (Limit: 1 request)';
    }
  }

  Color _getRelationshipColor(String relationship) {
    final scheme = Theme.of(context).colorScheme;
    switch (relationship) {
      case 'friend':
        return scheme.primary;
      case 'best_friend':
        return scheme.tertiary;
      case 'family':
        return Colors.green;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unblockRequestsAsync = ref.watch(unblockRequestsStreamProvider);

    return unblockRequestsAsync.when(
      data: (unblockRequests) {
        if (unblockRequests.isEmpty) {
          return const Center(
            child: Text('No unblock requests at the moment.'),
          );
        }

        if (_isLoadingRelationships) {
          return const Center(child: CircularProgressIndicator());
        }

        final categorizedRequests = _categorizeRequests(unblockRequests);

        return ListView.builder(
          itemCount: categorizedRequests.length,
          itemBuilder: (context, categoryIndex) {
            final relationship =
                categorizedRequests.keys.elementAt(categoryIndex);
            final requests = categorizedRequests[relationship]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: _getRelationshipColor(relationship)
                      .withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group,
                        color: _getRelationshipColor(relationship),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getRelationshipDisplayName(relationship),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getRelationshipColor(relationship),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRelationshipColor(relationship),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Requests in this category
                ...requests.map((request) => Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: FutureBuilder<String?>(
                          future: _getUsername(request.fromUserId),
                          builder: (context, snapshot) {
                            final username =
                                snapshot.data ?? 'User: ${request.fromUserId}';
                            return Text(username);
                          },
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (request.message != null &&
                                request.message!.isNotEmpty)
                              Text('Message: ${request.message}'),
                            Text(
                              'Requested: ${_formatDate(request.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                              onPressed: () async {
                                await ref
                                    .read(unblockRequestProvider.notifier)
                                    .acceptUnblockRequest(request.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Unblock request accepted')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Reject',
                              onPressed: () async {
                                await ref
                                    .read(unblockRequestProvider.notifier)
                                    .rejectUnblockRequest(request.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Unblock request rejected')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Future<String?> _getUsername(String userId) async {
    return await _relationshipService.getUsername(userId);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
