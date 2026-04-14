import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension DetailNavigation on BuildContext {
  Future<void> openMatchDetail(String matchId) {
    final safeMatchId = Uri.encodeComponent(matchId);
    final nextLocation = '/match/$safeMatchId';
    final currentPath = GoRouterState.of(this).uri.path;

    if (currentPath == nextLocation) {
      return Future<void>.value();
    }

    if (currentPath.startsWith('/match/')) {
      // Keep only one match detail on stack by replacing current match detail.
      pushReplacement(nextLocation);
      return Future<void>.value();
    }

    return push(nextLocation).then((_) {});
  }
}
