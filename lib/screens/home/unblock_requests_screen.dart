import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/unblock_requests_list.dart';
import '../../providers/unblock_request_provider.dart';
import '../../widgets/app_page_scaffold.dart';

class UnblockRequestsScreen extends ConsumerWidget {
  const UnblockRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unblockRequestsAsync = ref.watch(unblockRequestsStreamProvider);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('Unblock Requests'),
      ),
      child: unblockRequestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('No unblock requests at the moment.'),
            );
          }
          return const UnblockRequestsList();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
