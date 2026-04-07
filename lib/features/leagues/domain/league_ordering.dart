import 'package:eri_sports/data/db/app_database.dart';

const List<String> referenceLeagueOrder = [
  'premier league',
  'champions league',
  'africa cup of nations',
  'fifa 26',
  'caf champions league',
  'euro',
  'ligue 1',
  'bundesliga',
  'serie a',
  'europa league',
  'uefa super cup',
  'fifa world cup',
  'laliga',
  'saudi pro league',
  'fa cup',
];

const String kVirtualLeagueIdPrefix = 'virtual_league_';

enum LeagueCategory { international, domestic, other }

const Set<String> _internationalCanonicals = {
  'africa cup of nations',
  'fifa 26',
  'fifa world cup',
  'champions league',
  'caf champions league',
  'euro',
  'europa league',
  'uefa super cup',
};

const int _unknownLeagueRank = 100000;

final Map<String, int> _rankByCanonicalName = {
  for (var index = 0; index < referenceLeagueOrder.length; index++)
    referenceLeagueOrder[index]: index,
};

List<CompetitionRow> orderLeaguesForReference(List<CompetitionRow> leagues) {
  final sorted = List<CompetitionRow>.from(leagues);

  sorted.sort((a, b) {
    final rankA = referenceLeagueRank(a.name);
    final rankB = referenceLeagueRank(b.name);

    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }

    if (rankA == _unknownLeagueRank) {
      final displayOrderCompare = a.displayOrder.compareTo(b.displayOrder);
      if (displayOrderCompare != 0) {
        return displayOrderCompare;
      }
    }

    final nameCompare = _normalizeName(a.name).compareTo(_normalizeName(b.name));
    if (nameCompare != 0) {
      return nameCompare;
    }

    return a.id.compareTo(b.id);
  });

  return sorted;
}

List<CompetitionRow> ensureFeaturedInternationalLeagues(
  List<CompetitionRow> leagues,
) {
  final merged = List<CompetitionRow>.from(leagues);
  final canonicals = {
    for (final league in merged) canonicalLeagueName(league.name),
  };

  void ensure({
    required String canonical,
    required String id,
    required String name,
  }) {
    if (canonicals.contains(canonical)) {
      return;
    }

    merged.add(
      CompetitionRow(
        id: id,
        name: name,
        country: 'International',
        logoAssetKey: null,
        displayOrder: -1000,
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    canonicals.add(canonical);
  }

  ensure(
    canonical: 'africa cup of nations',
    id: '${kVirtualLeagueIdPrefix}afcon',
    name: 'AFCON',
  );
  ensure(
    canonical: 'fifa 26',
    id: '${kVirtualLeagueIdPrefix}fifa_26',
    name: 'FIFA 26',
  );

  return merged;
}

LeagueCategory leagueCategoryFor(CompetitionRow league) {
  final canonical = canonicalLeagueName(league.name);
  if (_internationalCanonicals.contains(canonical)) {
    return LeagueCategory.international;
  }

  final country = league.country;
  if (country != null && country.trim().isNotEmpty) {
    return LeagueCategory.domestic;
  }

  return LeagueCategory.other;
}

String leagueCategoryLabel(LeagueCategory category) {
  switch (category) {
    case LeagueCategory.international:
      return 'International Leagues';
    case LeagueCategory.domestic:
      return 'Domestic Leagues';
    case LeagueCategory.other:
      return 'Other Leagues';
  }
}

bool isVirtualLeagueId(String id) {
  return id.startsWith(kVirtualLeagueIdPrefix);
}

int referenceLeagueRank(String leagueName) {
  final canonical = canonicalLeagueName(leagueName);
  return _rankByCanonicalName[canonical] ?? _unknownLeagueRank;
}

String? canonicalLeagueNameOrNull(String leagueName) {
  final canonical = canonicalLeagueName(leagueName);
  return _rankByCanonicalName.containsKey(canonical) ? canonical : null;
}

String canonicalLeagueName(String leagueName) {
  final normalized = _normalizeName(leagueName);

  if (normalized.contains('premier league')) {
    return 'premier league';
  }
  if (normalized.contains('africa cup of nations') || normalized == 'afcon') {
    return 'africa cup of nations';
  }
  if (normalized == 'fifa 26' ||
      normalized == 'fifa26' ||
      normalized.contains('fifa world cup 2026') ||
      normalized.contains('world cup 2026')) {
    return 'fifa 26';
  }
  if (normalized.contains('caf champions league')) {
    return 'caf champions league';
  }
  if (normalized.contains('uefa champions league') ||
      normalized == 'champions league') {
    return 'champions league';
  }
  if (normalized == 'euro' ||
      normalized.startsWith('euro ') ||
      normalized.contains(' uefa euro')) {
    return 'euro';
  }
  if (normalized.contains('ligue 1')) {
    return 'ligue 1';
  }
  if (normalized.contains('bundesliga')) {
    return 'bundesliga';
  }
  if (normalized == 'serie a' || normalized.contains('serie a ')) {
    return 'serie a';
  }
  if (normalized.contains('uefa europa league') ||
      normalized == 'europa league') {
    return 'europa league';
  }
  if (normalized.contains('uefa super cup') || normalized == 'super cup') {
    return 'uefa super cup';
  }
  if (normalized.contains('fifa world cup') || normalized == 'world cup') {
    return 'fifa world cup';
  }
  if (normalized == 'laliga' || normalized == 'la liga') {
    return 'laliga';
  }
  if (normalized == 'saudi pro league' ||
      normalized == 'saudi professional league' ||
      normalized == 'roshn saudi league' ||
      normalized.contains('saudi pro league')) {
    return 'saudi pro league';
  }
  if (normalized == 'fa cup' || normalized.contains('english fa cup')) {
    return 'fa cup';
  }

  return normalized;
}

String _normalizeName(String input) {
  final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
}
