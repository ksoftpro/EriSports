import 'dart:io';

import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:flutter/material.dart';

class EntityBadge extends StatelessWidget {
  const EntityBadge({
    required this.entityId,
    required this.type,
    required this.resolver,
    this.size = 18,
    this.isCircular = true,
    super.key,
  });

  final String entityId;
  final SportsAssetType type;
  final LocalAssetResolver resolver;
  final double size;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedImageRef?>(
      future: resolver.resolveByEntityId(type: type, entityId: entityId),
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.secondary,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(4),
      ),
    );
  }
}
