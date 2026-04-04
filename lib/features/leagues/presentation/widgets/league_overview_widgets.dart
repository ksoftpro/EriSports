import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:flutter/material.dart';

class LeagueHeader extends StatelessWidget {
  const LeagueHeader({
    required this.competitionId,
    required this.resolver,
    required this.competitionName,
    required this.countryLabel,
    required this.seasonLabel,
    required this.onBack,
    required this.onNotify,
    required this.onFollowing,
    super.key,
  });

  final String competitionId;
  final LocalAssetResolver resolver;
  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final VoidCallback onBack;
  final VoidCallback onNotify;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF331A69), Color(0xFF4A278B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                _CircleIconButton(icon: Icons.arrow_back, onPressed: onBack),
                const Spacer(),
                _CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  onPressed: onNotify,
                ),
                const SizedBox(width: 8),
                _FollowingButton(onPressed: onFollowing),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _SeasonChip(label: seasonLabel),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: EntityBadge(
                    entityId: competitionId,
                    type: SportsAssetType.leagues,
                    resolver: resolver,
                    size: 42,
                    isCircular: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        competitionName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countryLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFE2D8FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueTopTabs extends StatelessWidget {
  const LeagueTopTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF4A278B),
      child: TabBar(
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFFCFBFFF),
        indicatorColor: Colors.white,
        indicatorWeight: 2.2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.only(right: 18),
        tabs: const [
          Tab(text: 'Table'),
          Tab(text: 'Fixtures'),
          Tab(text: 'News'),
          Tab(text: 'Player stats'),
          Tab(text: 'Team stats'),
        ],
      ),
    );
  }
}

class LeagueSegmentedControls extends StatelessWidget {
  const LeagueSegmentedControls({
    required this.selectedMode,
    required this.scopeLabel,
    required this.onModeChanged,
    required this.onScopeTap,
    super.key,
  });

  final String selectedMode;
  final String scopeLabel;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onScopeTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E7F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _SegmentedOption(
                    label: 'Short',
                    isSelected: selectedMode == 'Short',
                    onTap: () => onModeChanged('Short'),
                  ),
                  _SegmentedOption(
                    label: 'Full',
                    isSelected: selectedMode == 'Full',
                    onTap: () => onModeChanged('Full'),
                  ),
                  _SegmentedOption(
                    label: 'Form',
                    isSelected: selectedMode == 'Form',
                    onTap: () => onModeChanged('Form'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onScopeTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D7E5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scopeLabel,
                    style: const TextStyle(
                      color: Color(0xFF1A2030),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF1A2030),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LeagueStandingsHeader extends StatelessWidget {
  const LeagueStandingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Color(0xFF717B93),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 12),
      alignment: Alignment.center,
      child: const Row(
        children: [
          SizedBox(width: 6),
          SizedBox(width: 22, child: Text('#', style: textStyle)),
          Expanded(child: Text('Team', style: textStyle)),
          SizedBox(
            width: 36,
            child: Text('Pl', style: textStyle, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 38,
            child: Text('GD', style: textStyle, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 38,
            child: Text('Pts', style: textStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class LeagueStandingsRow extends StatelessWidget {
  const LeagueStandingsRow({
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.goalDiff,
    required this.points,
    required this.rowCount,
    required this.resolver,
    required this.onTap,
    super.key,
  });

  final int position;
  final String teamId;
  final String teamName;
  final int played;
  final int goalDiff;
  final int points;
  final int rowCount;
  final LocalAssetResolver resolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 8, right: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8ECF6))),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 26,
              decoration: BoxDecoration(
                color: _positionColor(position, rowCount),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: Text(
                '$position',
                style: const TextStyle(
                  color: Color(0xFF2A3142),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Row(
                children: [
                  EntityBadge(
                    entityId: teamId,
                    type: SportsAssetType.teams,
                    resolver: resolver,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF141A28),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$played',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF141A28),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                goalDiff > 0 ? '+$goalDiff' : '$goalDiff',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF141A28),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '$points',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF141A28),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _positionColor(int pos, int totalRows) {
    if (pos <= 4) {
      return const Color(0xFF2F7DFF);
    }
    if (pos <= 6) {
      return const Color(0xFF1DBB73);
    }
    if (pos >= totalRows - 2) {
      return const Color(0xFFE0415D);
    }
    return const Color(0x00000000);
  }
}

class _SegmentedOption extends StatelessWidget {
  const _SegmentedOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0x00000000),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected
                      ? const Color(0xFF151B28)
                      : const Color(0xFF5E6881),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0x2CFFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _FollowingButton extends StatelessWidget {
  const _FollowingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: const Color(0x2EFFFFFF),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: const Text(
          'Following',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x30FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x66FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
