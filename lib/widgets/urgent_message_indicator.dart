import 'package:flutter/material.dart';

class UrgentMessageIndicator extends StatelessWidget {
  final bool isUrgent;

  const UrgentMessageIndicator({
    super.key,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    if (!isUrgent) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'URGENT',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
