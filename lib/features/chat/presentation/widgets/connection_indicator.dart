import 'package:app/core/api/echo_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(echoConnectionStatusProvider);

    return statusAsync.when(
      data: (status) {
        Color color;
        String tooltip;
        if (status == 'connected') {
          color = Colors.green;
          tooltip = 'Echtzeit-Server verbunden';
        } else if (status == 'connecting') {
          color = Colors.orange;
          tooltip = 'Verbinde mit Echtzeit-Server...';
        } else {
          color = Colors.red;
          tooltip = 'Echtzeit-Server getrennt';
        }

        return Tooltip(
          message: tooltip,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
