import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final bool isGroup;
  final double radius;
  final VoidCallback? onTap;

  const AppAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.isGroup = false,
    this.radius = 20,
    this.onTap,
  });

  Widget _buildFallback(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: isGroup
          ? Icon(
              Icons.group,
              size: radius * 1.1,
              color: theme.colorScheme.onPrimaryContainer,
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.85,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    final url = avatarUrl?.trim();
    if (url == null || url.isEmpty) {
      avatar = _buildFallback(context);
    } else {
      avatar = CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, _) => _buildFallback(context),
        errorWidget: (context, _, __) => _buildFallback(context),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
