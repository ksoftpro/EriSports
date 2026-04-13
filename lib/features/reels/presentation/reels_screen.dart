import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ReelsScreen extends ConsumerWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reels'),
        actions: [
          IconButton(
            tooltip: 'Refresh reels',
            onPressed:
                () => ref
                    .read(daylySportMediaSnapshotProvider.notifier)
                    .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, __) => _EmptyReelsState(
              title: 'Unable to load local reels',
              message:
                  'The app could not scan daylySport media folders. Check storage permissions and refresh.',
            ),
        data: (snapshot) {
          final reelsSection = snapshot.section(DaylySportMediaSection.reels);
          final highlightFallback = snapshot
              .section(DaylySportMediaSection.highlights)
              .items
              .where((item) => item.isVideo)
              .toList(growable: false);

          final items = reelsSection.hasItems
              ? reelsSection.items
              : highlightFallback;

          if (items.isEmpty) {
            return _EmptyReelsState(
              title: 'No short videos found',
              message:
                  'Add files in ${reelsSection.scannedDirectories.join(' or ')} to populate reels.',
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _ReelCard(item: items[index]);
            },
          );
        },
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.item});

  final DaylySportMediaItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.type == DaylySportMediaType.image)
              Image.file(item.file, fit: BoxFit.cover)
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E232D), Color(0xFF0E1118)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 84,
                    color: Colors.white70,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.relativePath} • ${DateFormat('EEE d MMM HH:mm').format(item.lastModified.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReelsState extends StatelessWidget {
  const _EmptyReelsState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_filter_outlined, size: 44),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
