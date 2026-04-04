import 'package:flutter/material.dart';

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
    final name = competitionName.toLowerCase();

    for (final rule in _rules) {
      if (rule.matches(id, name)) {
        return rule.theme;
      }
    }

    return const LeagueVisualTheme(
      headerTop: Color(0xFF21304D),
      headerBottom: Color(0xFF334B76),
      tabBackground: Color(0xFF334B76),
      onHeader: Colors.white,
      onHeaderMuted: Color(0xFFD8E4FF),
    );
  }

  static const List<_LeagueThemeRule> _rules = [
    _LeagueThemeRule(
      ids: {'47'},
      nameTokens: {'premier'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF31135F),
        headerBottom: Color(0xFF4D1D85),
        tabBackground: Color(0xFF4D1D85),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFE2D6FF),
      ),
    ),
    _LeagueThemeRule(
      ids: {'42'},
      nameTokens: {'champions'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF08225A),
        headerBottom: Color(0xFF0F3A86),
        tabBackground: Color(0xFF0F3A86),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFD9E4FF),
      ),
    ),
    _LeagueThemeRule(
      ids: {'73'},
      nameTokens: {'europa'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF552406),
        headerBottom: Color(0xFF864112),
        tabBackground: Color(0xFF864112),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFFFE6D2),
      ),
    ),
    _LeagueThemeRule(
      ids: {'87'},
      nameTokens: {'laliga', 'la liga'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF62193F),
        headerBottom: Color(0xFF8F2A5D),
        tabBackground: Color(0xFF8F2A5D),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFF9DDE9),
      ),
    ),
    _LeagueThemeRule(
      ids: {'54'},
      nameTokens: {'bundesliga'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF7F0F19),
        headerBottom: Color(0xFFA91A24),
        tabBackground: Color(0xFFA91A24),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFFFE0E3),
      ),
    ),
    _LeagueThemeRule(
      ids: {'55'},
      nameTokens: {'serie a'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF0C3A72),
        headerBottom: Color(0xFF1457A8),
        tabBackground: Color(0xFF1457A8),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFDCEBFF),
      ),
    ),
    _LeagueThemeRule(
      ids: {'53'},
      nameTokens: {'ligue 1', 'ligue1'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF0E2E5D),
        headerBottom: Color(0xFF1C4C8C),
        tabBackground: Color(0xFF1C4C8C),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFDCE7FB),
      ),
    ),
    _LeagueThemeRule(
      ids: {'132'},
      nameTokens: {'fa cup'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF0E4B3A),
        headerBottom: Color(0xFF1D7358),
        tabBackground: Color(0xFF1D7358),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFD8F0E6),
      ),
    ),
    _LeagueThemeRule(
      ids: {'307'},
      nameTokens: {'saudi'},
      theme: LeagueVisualTheme(
        headerTop: Color(0xFF0D5A3D),
        headerBottom: Color(0xFF1C7E58),
        tabBackground: Color(0xFF1C7E58),
        onHeader: Colors.white,
        onHeaderMuted: Color(0xFFD7F2E6),
      ),
    ),
  ];
}

class _LeagueThemeRule {
  const _LeagueThemeRule({
    required this.ids,
    required this.nameTokens,
    required this.theme,
  });

  final Set<String> ids;
  final Set<String> nameTokens;
  final LeagueVisualTheme theme;

  bool matches(String id, String name) {
    if (ids.contains(id)) {
      return true;
    }
    for (final token in nameTokens) {
      if (name.contains(token)) {
        return true;
      }
    }
    return false;
  }
}
