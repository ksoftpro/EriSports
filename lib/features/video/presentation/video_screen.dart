import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
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

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video'),
        actions: [
          IconButton(
            tooltip: 'Refresh media',
            onPressed:
                () => ref
                    .read(daylySportMediaSnapshotProvider.notifier)
                    .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Highlights'),
            Tab(text: 'News'),
            Tab(text: 'Updates'),
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
          return TabBarView(
            controller: _tabs,
            children: [
              _SectionMediaGrid(
                title: 'Highlights',
                section: snapshot.section(DaylySportMediaSection.highlights),
              ),
              _SectionMediaGrid(
                title: 'News',
                section: snapshot.section(DaylySportMediaSection.news),
              ),
              _SectionMediaGrid(
                title: 'Updates',
                section: snapshot.section(DaylySportMediaSection.updates),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionMediaGrid extends StatelessWidget {
  const _SectionMediaGrid({required this.title, required this.section});

  final String title;
  final DaylySportMediaSectionSnapshot section;

  @override
  Widget build(BuildContext context) {
    if (section.items.isEmpty) {
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
                  'No $title media yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Drop local files into ${section.scannedDirectories.join(' or ')} and refresh.',
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
      itemCount: section.items.length,
      itemBuilder: (context, index) {
        final item = section.items[index];
        return _MediaCard(item: item);
      },
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.item});

  final DaylySportMediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: item.type == DaylySportMediaType.image
                ? Image.file(item.file, fit: BoxFit.cover)
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
    );
  }
}
