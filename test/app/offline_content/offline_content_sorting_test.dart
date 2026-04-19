import 'dart:io';

import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sorts offline media items by unseen first and newest second', () {
    final olderUnseen = DaylySportMediaItem(
      file: File('older_unseen.mp4.esv'),
      relativePath: 'reels/older_unseen.mp4.esv',
      section: DaylySportMediaSection.reels,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 15, 10),
      sizeBytes: 10,
    );
    final newerSeen = DaylySportMediaItem(
      file: File('newer_seen.mp4.esv'),
      relativePath: 'reels/newer_seen.mp4.esv',
      section: DaylySportMediaSection.reels,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 17, 10),
      sizeBytes: 10,
    );
    final newerUnseen = DaylySportMediaItem(
      file: File('newer_unseen.mp4.esv'),
      relativePath: 'reels/newer_unseen.mp4.esv',
      section: DaylySportMediaSection.reels,
      type: DaylySportMediaType.video,
      lastModified: DateTime.utc(2026, 4, 18, 10),
      sizeBytes: 10,
    );

    final sorted = sortOfflineMediaItemsForDisplay(
      [olderUnseen, newerSeen, newerUnseen],
      <String>{offlineContentMediaItemId(newerSeen)},
    );

    expect(sorted, [newerUnseen, olderUnseen, newerSeen]);
  });

  test('sorts offline news items by unseen first and newest second', () {
    final olderUnseen = OfflineNewsMediaItem(
      file: File('older_unseen.png.esi'),
      lastModified: DateTime.utc(2026, 4, 15, 10),
      sizeBytes: 10,
    );
    final newerSeen = OfflineNewsMediaItem(
      file: File('newer_seen.png.esi'),
      lastModified: DateTime.utc(2026, 4, 17, 10),
      sizeBytes: 10,
    );
    final newerUnseen = OfflineNewsMediaItem(
      file: File('newer_unseen.png.esi'),
      lastModified: DateTime.utc(2026, 4, 18, 10),
      sizeBytes: 10,
    );

    final sorted = sortOfflineNewsItemsForDisplay(
      [olderUnseen, newerSeen, newerUnseen],
      <String>{offlineContentNewsItemId(newerSeen)},
    );

    expect(sorted, [newerUnseen, olderUnseen, newerSeen]);
  });
}