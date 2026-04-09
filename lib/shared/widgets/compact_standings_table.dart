import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:eri_sports/shared/widgets/team_badge.dart';
import 'package:flutter/material.dart';

@immutable
class CompactStandingsTableRow {
  const CompactStandingsTableRow({
    required this.teamId,
    required this.teamName,
    required this.shortName,
    required this.position,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.scores,
    required this.goalDiff,
    required this.points,
    this.form,
    this.qualColorHex,
    this.isHighlighted = false,
    this.nextTeamId,
    this.nextTeamName,
  });

  final String teamId;
  final String teamName;
  final String shortName;
  final int position;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final String scores;
  final int goalDiff;
  final int points;
  final String? form;
  final String? qualColorHex;
  final bool isHighlighted;
  final String? nextTeamId;
  final String? nextTeamName;

  String get displayName {
    final compact = shortName.trim();
    if (compact.isNotEmpty) {
      return compact;
    }
    return teamName;
  }
}

@immutable
class CompactStandingsHeaderLabels {
  const CompactStandingsHeaderLabels({
    this.team = 'Team',
    this.played = 'PL',
    this.wins = 'W',
    this.draws = 'D',
    this.losses = 'L',
    this.scores = '+/-',
    this.goalDiff = 'GD',
    this.points = 'PTS',
    this.form = 'Form',
    this.next = 'Next',
  });

  final String team;
  final String played;
  final String wins;
  final String draws;
  final String losses;
  final String scores;
  final String goalDiff;
  final String points;
  final String form;
  final String next;
}

typedef CompactStandingsFallbackStripColor =
    Color Function(CompactStandingsTableRow row, int rowCount);

class CompactStandingsTable extends StatelessWidget {
  const CompactStandingsTable({
    required this.rows,
    required this.resolver,
    required this.onRowTap,
    this.showForm = true,
    this.showNext = false,
    this.headerLabels = const CompactStandingsHeaderLabels(),
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 6),
    this.highlightColor = const Color(0xFFEFF4FF),
    this.defaultStripColor = const Color(0xFFAAB3C2),
    this.fallbackStripColor,
    this.tableBadgeSource = 'standings.table',
    this.nextBadgeSource = 'standings.table.next',
    super.key,
  });

  final List<CompactStandingsTableRow> rows;
  final LocalAssetResolver resolver;
  final ValueChanged<CompactStandingsTableRow> onRowTap;
  final bool showForm;
  final bool showNext;
  final CompactStandingsHeaderLabels headerLabels;
  final EdgeInsetsGeometry padding;
  final Color highlightColor;
  final Color defaultStripColor;
  final CompactStandingsFallbackStripColor? fallbackStripColor;
  final String tableBadgeSource;
  final String nextBadgeSource;

  static const double _rowHeight = 32;
  static const double _headerHeight = 24;
  static const double _leftInset = 2;
  static const double _rightInset = 2;
  static const double _gap = 2;
  static const double _stripWidth = 2;
  static const double _positionWidth = 15;
  static const double _teamCellWidth = 132;
  static const double _playedWidth = 18;
  static const double _metricWidth = 18;
  static const double _goalDiffWidth = 22;
  static const double _pointsWidth = 24;
  static const double _formWidth = 56;
  static const double _nextWidth = 34;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: SizedBox(
        width: _tableWidth,
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE4E8ED)),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF1F5)),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _buildRow(row, rows.length);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const style = TextStyle(
      color: Color(0xFF657082),
      fontWeight: FontWeight.w700,
      fontSize: 9.8,
    );

    return Container(
      height: _headerHeight,
      padding: const EdgeInsets.fromLTRB(_leftInset, 0, _rightInset, 0),
      alignment: Alignment.center,
      child: Row(
        children: [
          const SizedBox(width: _stripWidth + _gap),
          const SizedBox(width: _positionWidth, child: Text('#', style: style)),
          const SizedBox(width: _gap),
          SizedBox(
            width: _teamCellWidth,
            child: Text(headerLabels.team, style: style),
          ),
          _headerCell(headerLabels.played, _playedWidth),
          _headerCell(headerLabels.wins, _metricWidth),
          _headerCell(headerLabels.draws, _metricWidth),
          _headerCell(headerLabels.losses, _metricWidth),
          _headerCell(headerLabels.goalDiff, _goalDiffWidth),
          _headerCell(headerLabels.points, _pointsWidth),
          if (showForm)
            SizedBox(
              width: _formWidth,
              child: Text(
                headerLabels.form,
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          if (showNext)
            SizedBox(
              width: _nextWidth,
              child: Text(
                headerLabels.next,
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(CompactStandingsTableRow row, int rowCount) {
    final qualColor =
        _parseHexColor(row.qualColorHex) ??
        fallbackStripColor?.call(row, rowCount) ??
        defaultStripColor;

    return InkWell(
      onTap: () => onRowTap(row),
      child: Container(
        height: _rowHeight,
        padding: const EdgeInsets.fromLTRB(_leftInset, 0, _rightInset, 0),
        decoration:
            row.isHighlighted
                ? BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(7),
                )
                : null,
        child: Row(
          children: [
            Container(
              width: _stripWidth,
              height: 18,
              decoration: BoxDecoration(
                color: qualColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _positionWidth,
              child: Text(
                '${row.position}',
                style: const TextStyle(
                  color: Color(0xFF1D2533),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.2,
                ),
              ),
            ),
            const SizedBox(width: _gap),
            SizedBox(
              width: _teamCellWidth,
              child: Row(
                children: [
                  TeamBadge(
                    teamId: row.teamId,
                    teamName: row.teamName,
                    resolver: resolver,
                    source: tableBadgeSource,
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      row.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A2230),
                        fontWeight: FontWeight.w700,
                        fontSize: 10.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _metricCell('${row.played}', _playedWidth),
            _metricCell('${row.wins}', _metricWidth),
            _metricCell('${row.draws}', _metricWidth),
            _metricCell('${row.losses}', _metricWidth),
            _metricCell(_goalDiffLabel(row.goalDiff), _goalDiffWidth),
            _metricCell('${row.points}', _pointsWidth, bold: true),
            if (showForm)
              SizedBox(width: _formWidth, child: _FormTokens(form: row.form)),
            if (showNext)
              SizedBox(
                width: _nextWidth,
                child:
                    row.nextTeamId == null &&
                            (row.nextTeamName == null ||
                                row.nextTeamName!.trim().isEmpty)
                        ? const Text(
                          '-',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF808A99),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                        : Center(
                          child: TeamBadge(
                            teamId: row.nextTeamId,
                            teamName: row.nextTeamName,
                            resolver: resolver,
                            source: nextBadgeSource,
                            size: 14,
                          ),
                        ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF657082),
          fontWeight: FontWeight.w700,
          fontSize: 9.8,
        ),
      ),
    );
  }

  Widget _metricCell(String text, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: const Color(0xFF222A38),
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontSize: 10.3,
        ),
      ),
    );
  }

  double get _tableWidth {
    var width =
        _leftInset +
        _rightInset +
        _stripWidth +
        _gap +
        _positionWidth +
        _gap +
        _teamCellWidth +
        _playedWidth +
        _metricWidth +
        _metricWidth +
        _metricWidth +
        _goalDiffWidth +
        _pointsWidth;
    if (showForm) {
      width += _formWidth;
    }
    if (showNext) {
      width += _nextWidth;
    }
    return width;
  }

  String _goalDiffLabel(int value) => value > 0 ? '+$value' : '$value';

  Color? _parseHexColor(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }

    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }
}

class _FormTokens extends StatelessWidget {
  const _FormTokens({required this.form});

  final String? form;

  @override
  Widget build(BuildContext context) {
    final tokens = (form ?? '')
        .toUpperCase()
        .replaceAll(RegExp('[^WDL]'), '')
        .split('')
        .where((token) => token.isNotEmpty)
        .take(5)
        .toList(growable: false);

    if (tokens.isEmpty) {
      return const Text(
        '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF7D8795),
          fontWeight: FontWeight.w600,
          fontSize: 9.8,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final token in tokens)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.4),
            child: Container(
              width: 10,
              height: 9,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tokenColor(token),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                token,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 5.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _tokenColor(String token) {
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
