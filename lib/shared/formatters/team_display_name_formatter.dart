class TeamDisplayNameFormatter {
  static String compactMatchName(String teamName, {String? shortName}) {
    final trimmed = teamName.trim();
    if (trimmed.isEmpty) {
      return teamName;
    }

    final normalized = _normalize(trimmed);
    final mapped = _knownAbbreviations[normalized];
    if (mapped != null) {
      return mapped;
    }

    final candidateShort = shortName?.trim();
    if (candidateShort != null &&
        candidateShort.isNotEmpty &&
        candidateShort.length < trimmed.length - 3 &&
        candidateShort.length <= 14) {
      return candidateShort;
    }

    return trimmed;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _knownAbbreviations = {
    'paris saint germain': 'PSG',
    'manchester city': 'Man City',
    'manchester united': 'Man United',
    'newcastle united': 'Newcastle',
    'nottingham forest': 'Nottm Forest',
    'tottenham hotspur': 'Tottenham',
    'wolverhampton wanderers': 'Wolves',
    'brighton and hove albion': 'Brighton',
    'atletico madrid': 'Atletico',
    'borussia monchengladbach': 'Gladbach',
    'west ham united': 'West Ham',
    'athletic club': 'Athletic',
  };
}
