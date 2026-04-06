import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';

class TeamBadge extends StatelessWidget {
  const TeamBadge({
    this.teamId,
    this.teamName,
    required this.resolver,
    required this.source,
    this.size = 18,
    this.isCircular = true,
    super.key,
  });

  final String? teamId;
  final String? teamName;
  final LocalAssetResolver resolver;
  final String source;
  final double size;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    return EntityBadge(
      entityId: teamId ?? '',
      entityName: teamName,
      type: SportsAssetType.teams,
      resolver: resolver,
      resolutionSource: source,
      size: size,
      isCircular: isCircular,
    );
  }
}
