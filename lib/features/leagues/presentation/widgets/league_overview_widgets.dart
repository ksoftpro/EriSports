import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/features/leagues/presentation/league_overview_providers.dart';
import 'package:eri_sports/features/leagues/presentation/league_theme_resolver.dart';
import 'package:eri_sports/shared/widgets/entity_badge.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';

class LeagueHeader extends StatelessWidget {
  const LeagueHeader({
    required this.competitionId,
    required this.resolver,
    required this.theme,
    required this.competitionName,
    required this.countryLabel,
    required this.seasonLabel,
    required this.isFollowing,
    required this.notificationsOn,
    required this.onBack,
    required this.onSeasonTap,
    required this.onNotify,
    required this.onFollowing,
    super.key,
  });

  final String competitionId;
  final LocalAssetResolver resolver;
  final LeagueVisualTheme theme;
  final String competitionName;
  final String countryLabel;
  final String seasonLabel;
  final bool isFollowing;
  final bool notificationsOn;
  final VoidCallback onBack;
  final VoidCallback onSeasonTap;
  final VoidCallback onNotify;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.headerTop, theme.headerBottom],
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
                _CircleIconButton(
                  icon: Icons.arrow_back,
                  onPressed: onBack,
                  color: theme.onHeader,
                ),
                const Spacer(),
                _CircleIconButton(
                  icon:
                      notificationsOn
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                  onPressed: onNotify,
                  color: theme.onHeader,
                ),
                const SizedBox(width: 8),
                _FollowingButton(
                  isFollowing: isFollowing,
                  onPressed: onFollowing,
                  textColor: theme.onHeader,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _SeasonChip(
                label: seasonLabel,
                onTap: onSeasonTap,
                textColor: theme.onHeader,
              ),
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
                          color: theme.onHeader,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        countryLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: theme.onHeaderMuted,
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
  const LeagueTopTabs({required this.theme, super.key});

  final LeagueVisualTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.tabBackground,
      child: TabBar(
        isScrollable: true,
        labelColor: theme.onHeader,
        unselectedLabelColor: theme.onHeaderMuted,
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
    required this.selectedScope,
    required this.onModeChanged,
    required this.onScopeChanged,
    super.key,
  });

  final LeagueTableMode selectedMode;
  final LeagueScopeMode selectedScope;
  final ValueChanged<LeagueTableMode> onModeChanged;
  final ValueChanged<LeagueScopeMode> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _SegmentedOption(
                    label: 'Short',
                    isSelected: selectedMode == LeagueTableMode.short,
                    onTap: () => onModeChanged(LeagueTableMode.short),
                  ),
                  _SegmentedOption(
                    label: 'Full',
                    isSelected: selectedMode == LeagueTableMode.full,
                    onTap: () => onModeChanged(LeagueTableMode.full),
                  ),
                  _SegmentedOption(
                    label: 'Form',
                    isSelected: selectedMode == LeagueTableMode.form,
                    onTap: () => onModeChanged(LeagueTableMode.form),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<LeagueScopeMode>(
            onSelected: onScopeChanged,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: LeagueScopeMode.overall,
                    child: Text('Overall'),
                  ),
                  const PopupMenuItem(
                    value: LeagueScopeMode.home,
                    child: Text('Home'),
                  ),
                  const PopupMenuItem(
                    value: LeagueScopeMode.away,
                    child: Text('Away'),
                  ),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.72),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _scopeLabel(selectedScope),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: scheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scopeLabel(LeagueScopeMode scope) {
    switch (scope) {
      case LeagueScopeMode.overall:
        return 'Overall';
      case LeagueScopeMode.home:
        return 'Home';
      case LeagueScopeMode.away:
        return 'Away';
    }
  }
}

class LeagueStandingsHeader extends StatelessWidget {
  const LeagueStandingsHeader({required this.mode, super.key});

  final LeagueTableMode mode;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withValues(alpha: 0.84),
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );

    final children = <Widget>[
      const SizedBox(width: 6),
      SizedBox(width: 22, child: Text('#', style: style)),
      Expanded(child: Text('Team', style: style)),
    ];

    if (mode == LeagueTableMode.short) {
      children.addAll([
        SizedBox(
          width: 36,
          child: Text('Pl', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 38,
          child: Text('GD', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 38,
          child: Text('Pts', style: style, textAlign: TextAlign.right),
        ),
      ]);
    } else if (mode == LeagueTableMode.full) {
      children.addAll([
        SizedBox(
          width: 34,
          child: Text('Pl', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 32,
          child: Text('W', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 32,
          child: Text('D', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 32,
          child: Text('L', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 36,
          child: Text('GF', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 36,
          child: Text('GA', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 38,
          child: Text('GD', style: style, textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 38,
          child: Text('Pts', style: style, textAlign: TextAlign.right),
        ),
      ]);
    } else {
      children.addAll([
        SizedBox(
          width: 110,
          child: Text('Form', style: style, textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 38,
          child: Text('Pts', style: style, textAlign: TextAlign.right),
        ),
      ]);
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 8, right: 12),
      alignment: Alignment.center,
      child: Row(children: children),
    );
  }
}

class LeagueStandingsRow extends StatelessWidget {
  const LeagueStandingsRow({
    required this.mode,
    required this.position,
    required this.teamId,
    required this.teamName,
    required this.played,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.form,
    required this.rowCount,
    required this.resolver,
    required this.onTap,
    super.key,
  });

  final LeagueTableMode mode;
  final int position;
  final String teamId;
  final String teamName;
  final int played;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final String? form;
  final int rowCount;
  final LocalAssetResolver resolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final children = <Widget>[
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
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Row(
          children: [
            TeamBadge(
              teamId: teamId,
              teamName: teamName,
              resolver: resolver,
              source: 'league.widgets.standings-row',
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    if (mode == LeagueTableMode.short) {
      children.addAll([
        _metricCell('$played', width: 36),
        _metricCell(_goalDiffLabel(goalDiff), width: 38),
        _metricCell('$points', width: 38, bold: true),
      ]);
    } else if (mode == LeagueTableMode.full) {
      children.addAll([
        _metricCell('$played', width: 34),
        _metricCell('$won', width: 32),
        _metricCell('$draw', width: 32),
        _metricCell('$lost', width: 32),
        _metricCell('$goalsFor', width: 36),
        _metricCell('$goalsAgainst', width: 36),
        _metricCell(_goalDiffLabel(goalDiff), width: 38),
        _metricCell('$points', width: 38, bold: true),
      ]);
    } else {
      children.addAll([
        SizedBox(width: 110, child: _FormBar(form: form)),
        _metricCell('$points', width: 38, bold: true),
      ]);
    }

    // Navigation to TeamScreen is disabled
    return InkWell(
      onTap: null,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 8, right: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8ECF6))),
        ),
        child: Row(children: children),
      ),
    );
  }

  String _goalDiffLabel(int value) => value > 0 ? '+$value' : '$value';

  Widget _metricCell(String text, {required double width, bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: const Color(0xFF1A2335),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
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

class _FormBar extends StatelessWidget {
  const _FormBar({required this.form});

  final String? form;

  @override
  Widget build(BuildContext context) {
    final normalized = (form ?? '').toUpperCase().replaceAll(
      RegExp('[^WDL]'),
      '',
    );
    final chars = normalized.split('').take(5).toList(growable: false);

    if (chars.isEmpty) {
      return Text(
        'No form',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodySmall?.color?.withValues(alpha: 0.84),
          fontSize: 11,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chars
          .map(
            (char) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _formColor(char),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  char,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Color _formColor(String token) {
    switch (token) {
      case 'W':
        return const Color(0xFF1FA463);
      case 'D':
        return const Color(0xFF9BA5BD);
      default:
        return const Color(0xFFE14E67);
    }
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
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.72),
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
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

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
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _FollowingButton extends StatelessWidget {
  const _FollowingButton({
    required this.isFollowing,
    required this.onPressed,
    required this.textColor,
  });

  final bool isFollowing;
  final VoidCallback onPressed;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color:
              isFollowing ? const Color(0x40FFFFFF) : const Color(0x2EFFFFFF),
          border: Border.all(color: const Color(0x66FFFFFF)),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  const _SeasonChip({
    required this.label,
    required this.onTap,
    required this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
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
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }
}
