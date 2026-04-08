enum MatchLifecycle { upcoming, live, finished }

class MatchScoreDisplay {
  const MatchScoreDisplay({
    required this.lifecycle,
    required this.centerLabel,
    required this.homeScoreLabel,
    required this.awayScoreLabel,
  });

  final MatchLifecycle lifecycle;
  final String centerLabel;
  final String? homeScoreLabel;
  final String? awayScoreLabel;

  bool get showNumericScore => homeScoreLabel != null && awayScoreLabel != null;
}

class MatchDisplayFormatter {
  static MatchLifecycle lifecycle({
    required String status,
    required DateTime kickoffUtc,
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();
    final lower = status.trim().toLowerCase();

    if (_isLive(lower)) {
      return MatchLifecycle.live;
    }
    if (_isNotPlayed(lower)) {
      return MatchLifecycle.upcoming;
    }
    if (_isFinished(lower)) {
      return MatchLifecycle.finished;
    }

    return kickoffUtc.isAfter(now)
        ? MatchLifecycle.upcoming
        : MatchLifecycle.finished;
  }

  static MatchScoreDisplay scoreDisplay({
    required String status,
    required DateTime kickoffUtc,
    required int? homeScore,
    required int? awayScore,
    DateTime? nowUtc,
  }) {
    final state = lifecycle(
      status: status,
      kickoffUtc: kickoffUtc,
      nowUtc: nowUtc,
    );

    if (state == MatchLifecycle.upcoming) {
      return const MatchScoreDisplay(
        lifecycle: MatchLifecycle.upcoming,
        centerLabel: 'vs',
        homeScoreLabel: null,
        awayScoreLabel: null,
      );
    }

    final home = homeScore ?? 0;
    final away = awayScore ?? 0;

    return MatchScoreDisplay(
      lifecycle: state,
      centerLabel: '$home - $away',
      homeScoreLabel: '$home',
      awayScoreLabel: '$away',
    );
  }

  static bool _isLive(String lower) {
    final words = _statusWords(lower);
    if (words.contains('live') ||
        words.contains('inplay') ||
        words.contains('playing') ||
        words.contains('ht')) {
      return true;
    }
    return lower.contains('in_play') || lower.contains('live');
  }

  static bool _isFinished(String lower) {
    final words = _statusWords(lower);
    if (words.contains('ft') ||
        words.contains('finished') ||
        words.contains('completed') ||
        words.contains('complete') ||
        words.contains('aet') ||
        words.contains('pen') ||
        words.contains('pens') ||
        words.contains('penalties') ||
        words.contains('final') ||
        words.contains('ended')) {
      return true;
    }

    return lower.contains('full time') || lower.contains('full-time');
  }

  static bool _isNotPlayed(String lower) {
    final words = _statusWords(lower);
    if (words.contains('scheduled') ||
        words.contains('upcoming') ||
        words.contains('notstarted') ||
        words.contains('ns') ||
        words.contains('tbd') ||
        words.contains('postponed') ||
        words.contains('cancelled') ||
        words.contains('canceled') ||
        words.contains('abandoned') ||
        words.contains('suspended') ||
        words.contains('delayed')) {
      return true;
    }

    // Some feeds provide only a kickoff clock token as status (for example: 19:30).
    if (RegExp(r'^\s*\d{1,2}:\d{2}\s*$').hasMatch(lower)) {
      return true;
    }

    return lower.contains('not started') ||
        lower.contains('postpon') ||
        lower.contains('cancel') ||
        lower.contains('suspend') ||
        lower.contains('delay');
  }

  static Set<String> _statusWords(String lower) {
    return lower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toSet();
  }
}
