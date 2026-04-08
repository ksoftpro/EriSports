import 'package:flutter/material.dart';
import 'package:eri_sports/features/leagues/domain/league_ordering.dart';

class LeagueVisualTheme {
  const LeagueVisualTheme({
    required this.headerTop,
    required this.headerBottom,
    required this.tabBackground,
    required this.onHeader,
    required this.onHeaderMuted,
  });

  final Color headerTop;
  final Color headerBottom;
  final Color tabBackground;
  final Color onHeader;
  final Color onHeaderMuted;
}

class LeagueThemeResolver {
  const LeagueThemeResolver._();

  static LeagueVisualTheme resolve({
    required String competitionId,
    required String competitionName,
  }) {
    final id = competitionId.trim();
    final canonical = canonicalLeagueName(competitionName);
    final name = competitionName.toLowerCase();

    final byId = _idOverrides[id];
    if (byId != null) {
      return byId;
    }

    final byCanonical = _canonicalThemes[canonical];
    if (byCanonical != null) {
      return byCanonical;
    }

    for (final entry in _tokenFallbacks.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }

    return _fallbackTheme;
  }

  static const LeagueVisualTheme _fallbackTheme = LeagueVisualTheme(
    headerTop: Color(0xFF203047),
    headerBottom: Color(0xFF2F455F),
    tabBackground: Color(0xFF2F455F),
    onHeader: Color(0xFFF8FBFF),
    onHeaderMuted: Color(0xFFD4DEE8),
  );

  static const Map<String, LeagueVisualTheme> _idOverrides = {
    '47': _premierLeague,
    '42': _championsLeague,
    '73': _europaLeague,
    '87': _laLiga,
    '54': _bundesliga,
    '55': _serieA,
    '53': _ligue1,
    '132': _faCup,
    '307': _saudiProLeague,
  };

  static const Map<String, LeagueVisualTheme> _canonicalThemes = {
    'premier league': _premierLeague,
    'champions league': _championsLeague,
    'europa league': _europaLeague,
    'uefa super cup': _uefaSuperCup,
    'fifa world cup': _fifaWorldCup,
    'africa cup of nations': _afcon,
    'caf champions league': _cafChampions,
    'euro': _euro,
    'laliga': _laLiga,
    'bundesliga': _bundesliga,
    'serie a': _serieA,
    'ligue 1': _ligue1,
    'saudi pro league': _saudiProLeague,
    'fa cup': _faCup,
    'fifa 26': _fifa26,
  };

  static const Map<String, LeagueVisualTheme> _tokenFallbacks = {
    'champions': _championsLeague,
    'europa': _europaLeague,
    'laliga': _laLiga,
    'la liga': _laLiga,
    'bundesliga': _bundesliga,
    'serie a': _serieA,
    'ligue 1': _ligue1,
    'saudi': _saudiProLeague,
    'fa cup': _faCup,
  };

  static const LeagueVisualTheme _premierLeague = LeagueVisualTheme(
    headerTop: Color(0xFF2B1152),
    headerBottom: Color(0xFF45206E),
    tabBackground: Color(0xFF45206E),
    onHeader: Color(0xFFFDFDFF),
    onHeaderMuted: Color(0xFFE0D8F0),
  );

  static const LeagueVisualTheme _championsLeague = LeagueVisualTheme(
    headerTop: Color(0xFF071F52),
    headerBottom: Color(0xFF133878),
    tabBackground: Color(0xFF133878),
    onHeader: Color(0xFFFDFEFF),
    onHeaderMuted: Color(0xFFDCE7FA),
  );

  static const LeagueVisualTheme _europaLeague = LeagueVisualTheme(
    headerTop: Color(0xFF4D260A),
    headerBottom: Color(0xFF6D3C13),
    tabBackground: Color(0xFF6D3C13),
    onHeader: Color(0xFFFFFCF8),
    onHeaderMuted: Color(0xFFF2DFD1),
  );

  static const LeagueVisualTheme _uefaSuperCup = LeagueVisualTheme(
    headerTop: Color(0xFF3A225F),
    headerBottom: Color(0xFF553080),
    tabBackground: Color(0xFF553080),
    onHeader: Color(0xFFFFFDFF),
    onHeaderMuted: Color(0xFFE9E0F2),
  );

  static const LeagueVisualTheme _fifaWorldCup = LeagueVisualTheme(
    headerTop: Color(0xFF65132A),
    headerBottom: Color(0xFF86203E),
    tabBackground: Color(0xFF86203E),
    onHeader: Color(0xFFFFFCFD),
    onHeaderMuted: Color(0xFFF2DDE3),
  );

  static const LeagueVisualTheme _afcon = LeagueVisualTheme(
    headerTop: Color(0xFF0E4A36),
    headerBottom: Color(0xFF1F6B50),
    tabBackground: Color(0xFF1F6B50),
    onHeader: Color(0xFFFCFFFD),
    onHeaderMuted: Color(0xFFDCEDE5),
  );

  static const LeagueVisualTheme _cafChampions = LeagueVisualTheme(
    headerTop: Color(0xFF0D3D3A),
    headerBottom: Color(0xFF1A5E5A),
    tabBackground: Color(0xFF1A5E5A),
    onHeader: Color(0xFFF8FFFE),
    onHeaderMuted: Color(0xFFD4EBE8),
  );

  static const LeagueVisualTheme _euro = LeagueVisualTheme(
    headerTop: Color(0xFF0A3E75),
    headerBottom: Color(0xFF1A5EA4),
    tabBackground: Color(0xFF1A5EA4),
    onHeader: Color(0xFFFDFEFF),
    onHeaderMuted: Color(0xFFDCEAF8),
  );

  static const LeagueVisualTheme _laLiga = LeagueVisualTheme(
    headerTop: Color(0xFF6D1739),
    headerBottom: Color(0xFF8F2C55),
    tabBackground: Color(0xFF8F2C55),
    onHeader: Color(0xFFFFFCFD),
    onHeaderMuted: Color(0xFFF1DDE5),
  );

  static const LeagueVisualTheme _bundesliga = LeagueVisualTheme(
    headerTop: Color(0xFF7E111C),
    headerBottom: Color(0xFFA0212A),
    tabBackground: Color(0xFFA0212A),
    onHeader: Color(0xFFFFFCFD),
    onHeaderMuted: Color(0xFFF2DEE1),
  );

  static const LeagueVisualTheme _serieA = LeagueVisualTheme(
    headerTop: Color(0xFF133E77),
    headerBottom: Color(0xFF1E5AA1),
    tabBackground: Color(0xFF1E5AA1),
    onHeader: Color(0xFFFDFEFF),
    onHeaderMuted: Color(0xFFDFE9F8),
  );

  static const LeagueVisualTheme _ligue1 = LeagueVisualTheme(
    headerTop: Color(0xFF102D56),
    headerBottom: Color(0xFF1D4A82),
    tabBackground: Color(0xFF1D4A82),
    onHeader: Color(0xFFFDFEFF),
    onHeaderMuted: Color(0xFFDCE6F7),
  );

  static const LeagueVisualTheme _saudiProLeague = LeagueVisualTheme(
    headerTop: Color(0xFF0D5439),
    headerBottom: Color(0xFF1E7753),
    tabBackground: Color(0xFF1E7753),
    onHeader: Color(0xFFFBFFFC),
    onHeaderMuted: Color(0xFFD8EBE0),
  );

  static const LeagueVisualTheme _faCup = LeagueVisualTheme(
    headerTop: Color(0xFF0C4A3A),
    headerBottom: Color(0xFF1A6C54),
    tabBackground: Color(0xFF1A6C54),
    onHeader: Color(0xFFF9FFFC),
    onHeaderMuted: Color(0xFFD7ECE2),
  );

  static const LeagueVisualTheme _fifa26 = LeagueVisualTheme(
    headerTop: Color(0xFF5E152A),
    headerBottom: Color(0xFF7E2944),
    tabBackground: Color(0xFF7E2944),
    onHeader: Color(0xFFFFFCFD),
    onHeaderMuted: Color(0xFFF1DEE4),
  );
}
