import 'dart:async';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/media/presentation/media_playback_screen.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  DateTime? _lastPrewarmScanAt;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);
    final badges = ref.watch(offlineContentBadgeCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video'),
        actions: [
          IconButton(
            tooltip: 'Refresh media',
            onPressed:
                () =>
                    ref
                        .read(daylySportMediaSnapshotProvider.notifier)
                        .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: _SectionTabLabel(
                label: 'Highlights',
                count: badges.videoHighlights,
              ),
            ),
            Tab(
              child: _SectionTabLabel(label: 'News', count: badges.videoNews),
            ),
            Tab(
              child: _SectionTabLabel(
                label: 'Updates',
                count: badges.videoUpdates,
              ),
            ),
          ],
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, __) => const Center(
              child: Text('Unable to load local daylySport media.'),
            ),
        data: (snapshot) {
          _scheduleEncryptedPrewarm(snapshot);
          return TabBarView(
            controller: _tabs,
            children: [
              _SectionMediaGrid(
                title: 'Highlights',
                section: snapshot.section(DaylySportMediaSection.highlights),
                onOpenMedia: _openMediaItem,
              ),
              _SectionMediaGrid(
                title: 'News',
                section: snapshot.section(DaylySportMediaSection.news),
                onOpenMedia: _openMediaItem,
              ),
              _SectionMediaGrid(
                title: 'Updates',
                section: snapshot.section(DaylySportMediaSection.updates),
                onOpenMedia: _openMediaItem,
              ),
            ],
          );
        },
      ),
    );
  }

  void _scheduleEncryptedPrewarm(DaylySportMediaSnapshot snapshot) {
    if (_lastPrewarmScanAt == snapshot.scannedAt) {
      return;
    }
    _lastPrewarmScanAt = snapshot.scannedAt;

    final encryptedVideos = <DaylySportMediaItem>[];
    for (final section in DaylySportMediaSection.values) {
      final items = snapshot.section(section).items;
      for (final item in items) {
        if (item.isVideo && item.isEncrypted) {
          encryptedVideos.add(item);
        }
      }
    }

    if (encryptedVideos.isEmpty) {
      return;
    }

    final service = ref.read(appServicesProvider).encryptedMediaService;
    unawaited(
      service.prewarmPlayableFiles(
        encryptedVideos.map((item) => item.file),
        maxItems: 6,
      ),
    );
  }

  void _openMediaItem(DaylySportMediaItem item) {
    unawaited(
      ref
          .read(offlineContentRefreshControllerProvider.notifier)
          .markMediaItemSeen(item),
    );
    if (item.isVideo && item.isEncrypted) {
      final service = ref.read(appServicesProvider).encryptedMediaService;
      unawaited(service.prewarmPlayableFile(item.file));
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MediaPlaybackScreen(item: item)));
  }
}

class _SectionTabLabel extends StatelessWidget {
  const _SectionTabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionMediaGrid extends StatelessWidget {
  const _SectionMediaGrid({
    required this.title,
    required this.section,
    required this.onOpenMedia,
  });

  final String title;
  final DaylySportMediaSectionSnapshot section;
  final ValueChanged<DaylySportMediaItem> onOpenMedia;

  @override
  Widget build(BuildContext context) {
    final items = section.videoItems;

    if (items.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_collection_outlined, size: 44),
                const SizedBox(height: 12),
                Text(
                  'No $title videos yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Drop encrypted videos into ${section.scannedDirectories.join(' or ')} and refresh.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 252,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MediaCard(item: item, onOpen: onOpenMedia);
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item, required this.onOpen});

  final DaylySportMediaItem item;
  final ValueChanged<DaylySportMediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () => onOpen(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  item.type == DaylySportMediaType.image
                      ? SecureFileImage(
                        sourceFile: item.file,
                        fit: BoxFit.cover,
                      )
                      : ColoredBox(
                        color: const Color(0xFF141A24),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Text(
                item.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                '${item.relativePath} • ${DateFormat('d MMM HH:mm').format(item.lastModified.toLocal())}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
