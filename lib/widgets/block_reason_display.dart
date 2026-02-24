import 'package:flutter/material.dart';

class BlockReasonDisplay extends StatelessWidget {
  final String? blockReason;
  final VoidCallback? onSendUnblockRequest;
  final VoidCallback? onUnblock;

  const BlockReasonDisplay({
    super.key,
    required this.blockReason,
    this.onSendUnblockRequest,
    this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You are blocked.',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            blockReason ?? 'No reason provided.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (onSendUnblockRequest != null)
            ElevatedButton(
              onPressed: onSendUnblockRequest,
              child: const Text('Send Unblock Request'),
            )
          else if (onUnblock != null)
            ElevatedButton(
              onPressed: onUnblock,
              child: const Text('Unblock'),
            ),
        ],
      ),
    );
  }
}
