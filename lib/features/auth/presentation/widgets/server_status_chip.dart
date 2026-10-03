import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/server_health_provider.dart';

class ServerStatusChip extends ConsumerWidget {
  const ServerStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(serverHealthProvider);

    Color dotColor = Colors.orange;
    String label = 'Verbindung wird geprüft...';
    IconData? trailingIcon;

    switch (status) {
      case ServerStatus.online:
        dotColor = Colors.green;
        label = 'Server online';
        break;
      case ServerStatus.checking:
        dotColor = Colors.orange;
        label = 'Verbindung wird geprüft...';
        break;
      case ServerStatus.offline:
        dotColor = Colors.red;
        label = 'Server offline (tippen zum Prüfen)';
        trailingIcon = Icons.refresh;
        break;
    }

    return InkWell(
      onTap: () => ref.read(serverHealthProvider.notifier).checkHealth(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: dotColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dotColor.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dotColor,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 14, color: dotColor),
            ],
          ],
        ),
      ),
    );
  }
}
