import 'dart:io';

import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:flutter/material.dart';

class EntityBadge extends StatelessWidget {
  const EntityBadge({
    required this.entityId,
    required this.type,
    required this.resolver,
    this.entityName,
    this.size = 18,
    this.isCircular = true,
    super.key,
  });

  final String entityId;
  final SportsAssetType type;
  final LocalAssetResolver resolver;
  final String? entityName;
  final double size;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedImageRef?>(
      future: resolver.resolve(
        type: type,
        entityId: entityId,
        entityName: entityName,
      ),
      builder: (context, snapshot) {
        final imageRef = snapshot.data;

        if (imageRef == null) {
          return _fallback(context);
        }

        final imageWidget = imageRef.isFile
            ? Image.file(
                File(imageRef.path),
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Image.asset(
                imageRef.path,
                width: size,
                height: size,
                fit: BoxFit.cover,
              );

        if (isCircular) {
          return ClipOval(child: imageWidget);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: imageWidget,
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = _fallbackLabel(entityName ?? entityId);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondary,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSecondary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          height: 1,
        ),
      ),
    );
  }

  String _fallbackLabel(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return '?';
    }

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final text = parts.first;
      return text.length >= 2
          ? text.substring(0, 2).toUpperCase()
          : text.toUpperCase();
    }

    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts[1].isNotEmpty ? parts[1][0] : '';
    final joined = '$a$b'.trim();
    return joined.isEmpty ? '?' : joined.toUpperCase();
  }
}
