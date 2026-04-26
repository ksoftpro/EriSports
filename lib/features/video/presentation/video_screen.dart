import 'dart:async';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/media/presentation/media_playback_screen.dart';
import 'package:eri_sports/features/media/presentation/video_list_layout_controller.dart';
import 'package:eri_sports/shared/widgets/offline_content_delete_progress_scope.dart';
import 'package:eri_sports/shared/widgets/new_content_badge.dart';
import 'package:eri_sports/shared/widgets/offline_video_thumbnail.dart';
import 'package:eri_sports/shared/widgets/pending_verification_placeholder.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  DateTime? _lastPrewarmScanAt;
  bool _selectionMode = false;
  bool _isDeleting = false;
  String? _selectedVideoCategoryKey;
  final Set<String> _selectedMediaIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);
    final deleteProgress = ref.watch(offlineContentDeletionProgressProvider);
    final seenItemIds = ref.watch(offlineSeenItemIdsProvider);
    final verifiedItemIds = ref.watch(offlineActiveVerifiedItemIdsProvider);
    final layoutMode = ref.watch(videoListLayoutModeProvider);
    final snapshot = mediaAsync.valueOrNull;
    final categories =
        snapshot == null
            ? const <DaylySportMediaCategoryGroup>[]
            : _videoCategoriesForSnapshot(snapshot, seenItemIds);
    final selectedCategory = _selectedVideoCategory(categories);
    final allItems =
        snapshot == null
            ? const <DaylySportMediaItem>[]
            : _allVideoItems(snapshot);
    final selectedCount = _selectedMediaIds.length;

    return DefaultTabController(
      length: categories.isEmpty ? 1 : categories.length,
      initialIndex: _selectedVideoCategoryIndex(categories),
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode ? 'Select videos ($selectedCount)' : 'Video',
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _isDeleting ? null : _clearSelection,
              icon: const Icon(Icons.close),
            )
          else if (allItems.isNotEmpty)
            IconButton(
              tooltip: 'Select videos',
              onPressed: _isDeleting ? null : () => _setSelectionMode(true),
              icon: const Icon(Icons.checklist_rounded),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Delete selected videos',
              onPressed:
                  _isDeleting || selectedCount == 0
                      ? null
                      : () => _deleteSelectedMedia(snapshot),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          PopupMenuButton<VideoListLayoutMode>(
            tooltip: 'Change video layout',
            initialValue: layoutMode,
            onSelected:
                _isDeleting
                    ? null
                    : (value) {
                      unawaited(
                        ref
                            .read(videoListLayoutModeProvider.notifier)
                            .setMode(value),
                      );
                    },
            itemBuilder: (context) {
              return [
                for (final mode in VideoListLayoutMode.values)
                  PopupMenuItem<VideoListLayoutMode>(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(mode.icon, size: 18),
                        const SizedBox(width: 10),
                        Text(mode.label),
                      ],
                    ),
                  ),
              ];
            },
            icon: Icon(layoutMode.icon),
          ),
          IconButton(
            tooltip: 'Refresh media',
            onPressed:
                _isDeleting
                    ? null
                    : () =>
                        ref
                            .read(daylySportMediaSnapshotProvider.notifier)
                            .refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom:
            categories.isEmpty
                ? null
                : TabBar(
                    isScrollable: true,
                    onTap: (index) {
                      final nextKey = categories[index].key;
                      if (_selectedVideoCategoryKey == nextKey) {
                        return;
                      }
                      setState(() {
                        _selectedVideoCategoryKey = nextKey;
                      });
                    },
                    tabs: [
                      for (final category in categories)
                        Tab(
                          child: _SectionTabLabel(
                            label: category.label,
                            count: _unseenCountForCategory(category, seenItemIds),
                          ),
                        ),
                    ],
                  ),
      ),
      body: OfflineContentDeleteProgressScope(
        progress: deleteProgress,
        child: mediaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, __) => const Center(
                child: Text('Unable to load local daylySport media.'),
              ),
          data: (snapshot) {
            _scheduleEncryptedPrewarm(snapshot, verifiedItemIds);
            if (selectedCategory == null) {
              return _VideoEmptyState(rootPath: snapshot.rootDirectory.path);
            }
            return _SectionMediaGrid(
              title: selectedCategory.label,
              emptyStateDirectories: <String>[snapshot.rootDirectory.path],
              items: selectedCategory.items,
              seenItemIds: seenItemIds,
              verifiedItemIds: verifiedItemIds,
              layoutMode: layoutMode,
              onOpenMedia: _openMediaItem,
              isSelectionMode: _selectionMode,
              selectedIds: _selectedMediaIds,
              onToggleSelection: _toggleMediaSelection,
              onStartSelection: _startSelection,
              onDeleteMedia: _deleteSingleMedia,
            );
          },
        ),
      ),
      ),
    );
  }

  void _scheduleEncryptedPrewarm(
    DaylySportMediaSnapshot snapshot,
    Set<String>? verifiedItemIds,
  ) {
    if (_lastPrewarmScanAt == snapshot.scannedAt) {
      return;
    }
    _lastPrewarmScanAt = snapshot.scannedAt;

    final encryptedVideos = <DaylySportMediaItem>[];
    for (final section in DaylySportMediaSection.values) {
      final items = snapshot.section(section).items;
      for (final item in items) {
        if (item.isVideo &&
            item.isEncrypted &&
            (verifiedItemIds == null ||
                isOfflineMediaItemVerified(item, verifiedItemIds))) {
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
    if (_selectionMode || _isDeleting) {
      return;
    }
    final verifiedItemIds = ref.read(offlineActiveVerifiedItemIdsProvider);
    if (
      verifiedItemIds != null &&
      !isOfflineMediaItemVerified(item, verifiedItemIds)
    ) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This content is pending official verification.'),
        ),
      );
      return;
    }
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

  List<DaylySportMediaItem> _allVideoItems(DaylySportMediaSnapshot snapshot) {
    return snapshot.allVideoItems();
  }

  List<DaylySportMediaCategoryGroup> _videoCategoriesForSnapshot(
    DaylySportMediaSnapshot snapshot,
    Set<String> seenItemIds,
  ) {
    final grouped = <String, _VideoCategoryAccumulator>{};
    for (final item in snapshot.allVideoItems()) {
      final key = item.categoryKey ?? item.section.name;
      final label = item.categoryLabel ?? sectionLabel(item.section);
      final bucket = grouped.putIfAbsent(
        key,
        () => _VideoCategoryAccumulator(key: key, label: label),
      );
      bucket.items.add(item);
    }

    final categories = [
      for (final bucket in grouped.values)
        DaylySportMediaCategoryGroup(
          key: bucket.key,
          label: bucket.label,
          items: sortOfflineMediaItemsForDisplay(bucket.items, seenItemIds),
        ),
    ];
    categories.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return categories;
  }

  DaylySportMediaCategoryGroup? _selectedVideoCategory(
    List<DaylySportMediaCategoryGroup> categories,
  ) {
    if (categories.isEmpty) {
      return null;
    }
    final selectedKey = _selectedVideoCategoryKey;
    if (selectedKey == null) {
      return categories.first;
    }
    for (final category in categories) {
      if (category.key == selectedKey) {
        return category;
      }
    }
    return categories.first;
  }

  int _selectedVideoCategoryIndex(
    List<DaylySportMediaCategoryGroup> categories,
  ) {
    if (categories.isEmpty) {
      return 0;
    }
    final selected = _selectedVideoCategory(categories);
    final index = categories.indexOf(selected!);
    return index < 0 ? 0 : index;
  }

  int _unseenCountForCategory(
    DaylySportMediaCategoryGroup category,
    Set<String> seenItemIds,
  ) {
    var unseenCount = 0;
    for (final item in category.items) {
      if (!isOfflineMediaItemSeen(item, seenItemIds)) {
        unseenCount += 1;
      }
    }
    return unseenCount;
  }

  void _setSelectionMode(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = value;
      if (!value) {
        _selectedMediaIds.clear();
      }
    });
  }

  void _clearSelection() {
    _setSelectionMode(false);
  }

  void _startSelection(DaylySportMediaItem item) {
    if (_isDeleting) {
      return;
    }
    final itemId = offlineContentMediaItemId(item);
    setState(() {
      _selectionMode = true;
      _selectedMediaIds
        ..clear()
        ..add(itemId);
    });
  }

  void _toggleMediaSelection(DaylySportMediaItem item) {
    if (_isDeleting) {
      return;
    }
    final itemId = offlineContentMediaItemId(item);
    setState(() {
      _selectionMode = true;
      if (!_selectedMediaIds.add(itemId)) {
        _selectedMediaIds.remove(itemId);
      }
      if (_selectedMediaIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSingleMedia(DaylySportMediaItem item) async {
    final confirmed = await _confirmDelete(context, count: 1, label: 'video');
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(mediaItems: [item]);
  }

  Future<void> _deleteSelectedMedia(DaylySportMediaSnapshot? snapshot) async {
    if (snapshot == null || _selectedMediaIds.isEmpty) {
      return;
    }

    final selected = _allVideoItems(snapshot)
        .where(
          (item) => _selectedMediaIds.contains(offlineContentMediaItemId(item)),
        )
        .toList(growable: false);
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }

    final confirmed = await _confirmDelete(
      context,
      count: selected.length,
      label: 'video',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(mediaItems: selected, clearSelectionAfter: true);
  }

  Future<void> _runDeletion({
    required List<DaylySportMediaItem> mediaItems,
    bool clearSelectionAfter = false,
  }) async {
    if (mediaItems.isEmpty) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final result = await ref
          .read(offlineContentRefreshControllerProvider.notifier)
          .deleteItems(mediaItems: mediaItems);
      if (!mounted) {
        return;
      }
      if (clearSelectionAfter) {
        _clearSelection();
      }
      final message = _deletionSummary(result, singularLabel: 'video');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
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
    required this.emptyStateDirectories,
    required this.items,
    required this.seenItemIds,
    required this.verifiedItemIds,
    required this.layoutMode,
    required this.onOpenMedia,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.onDeleteMedia,
  });

  final String title;
  final List<String> emptyStateDirectories;
  final List<DaylySportMediaItem> items;
  final Set<String> seenItemIds;
  final Set<String>? verifiedItemIds;
  final VideoListLayoutMode layoutMode;
  final ValueChanged<DaylySportMediaItem> onOpenMedia;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<DaylySportMediaItem> onToggleSelection;
  final ValueChanged<DaylySportMediaItem> onStartSelection;
  final ValueChanged<DaylySportMediaItem> onDeleteMedia;

  @override
  Widget build(BuildContext context) {
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
                  emptyStateDirectories.isEmpty
                      ? 'Import encrypted videos into an internal storage category folder and refresh.'
                      : 'Drop encrypted videos into ${emptyStateDirectories.join(' or ')} and refresh.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    switch (layoutMode) {
      case VideoListLayoutMode.details:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return _MediaCard(
              item: item,
              onOpen: onOpenMedia,
              isSelectionMode: isSelectionMode,
              isSelected: selectedIds.contains(offlineContentMediaItemId(item)),
              onToggleSelection: () => onToggleSelection(item),
              onStartSelection: () => onStartSelection(item),
              onDelete: () => onDeleteMedia(item),
              isNew: !isOfflineMediaItemSeen(item, seenItemIds),
              isVerified:
                  verifiedItemIds == null
                      ? true
                    : isOfflineMediaItemVerified(item, verifiedItemIds!),
              layoutMode: layoutMode,
            );
          },
        );
      case VideoListLayoutMode.tiles:
      case VideoListLayoutMode.largeThumbnails:
      case VideoListLayoutMode.mediumThumbnails:
      case VideoListLayoutMode.smallThumbnails:
        final metrics = _gridMetricsFor(layoutMode);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: metrics.maxCrossAxisExtent,
            mainAxisExtent: metrics.mainAxisExtent,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _MediaCard(
              item: item,
              onOpen: onOpenMedia,
              isSelectionMode: isSelectionMode,
              isSelected: selectedIds.contains(offlineContentMediaItemId(item)),
              onToggleSelection: () => onToggleSelection(item),
              onStartSelection: () => onStartSelection(item),
              onDelete: () => onDeleteMedia(item),
              isNew: !isOfflineMediaItemSeen(item, seenItemIds),
              isVerified:
                  verifiedItemIds == null
                      ? true
                    : isOfflineMediaItemVerified(item, verifiedItemIds!),
              layoutMode: layoutMode,
            );
          },
        );
    }
  }

  _VideoGridMetrics _gridMetricsFor(VideoListLayoutMode layoutMode) {
    switch (layoutMode) {
      case VideoListLayoutMode.tiles:
        return const _VideoGridMetrics(360, 250);
      case VideoListLayoutMode.largeThumbnails:
        return const _VideoGridMetrics(420, 284);
      case VideoListLayoutMode.mediumThumbnails:
        return const _VideoGridMetrics(320, 238);
      case VideoListLayoutMode.smallThumbnails:
        return const _VideoGridMetrics(220, 194);
      case VideoListLayoutMode.details:
        return const _VideoGridMetrics(360, 252);
    }
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.item,
    required this.onOpen,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.onDelete,
    required this.isNew,
    required this.isVerified,
    required this.layoutMode,
  });

  final DaylySportMediaItem item;
  final ValueChanged<DaylySportMediaItem> onOpen;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onStartSelection;
  final VoidCallback onDelete;
  final bool isNew;
  final bool isVerified;
  final VideoListLayoutMode layoutMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);
    final timestamp = DateFormat(
      'd MMM HH:mm',
    ).format(item.lastModified.toLocal());
    final isDetails = layoutMode == VideoListLayoutMode.details;
    final aspectRatio = switch (layoutMode) {
      VideoListLayoutMode.largeThumbnails => 16 / 10,
      VideoListLayoutMode.smallThumbnails => 4 / 3,
      _ => 16 / 9,
    };

    final thumbnail = AspectRatio(
      aspectRatio: aspectRatio,
      child:
          !isVerified
              ? const PendingVerificationPlaceholder(compact: true)
              : item.type == DaylySportMediaType.image
              ? SecureFileImage(sourceFile: item.file, fit: BoxFit.cover)
              : OfflineVideoThumbnail(
                item: item,
                maxDimension: switch (layoutMode) {
                  VideoListLayoutMode.largeThumbnails => 640,
                  VideoListLayoutMode.mediumThumbnails => 480,
                  VideoListLayoutMode.smallThumbnails => 320,
                  VideoListLayoutMode.tiles => 420,
                  VideoListLayoutMode.details => 360,
                },
              ),
    );

    final actionOverlay = Positioned(
      right: 6,
      top: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelectionMode)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? scheme.primary : Colors.white,
                ),
              ),
            )
          else
            IconButton.filledTonal(
              tooltip: 'Delete video',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );

    final newBadgeOverlay = Positioned(
      left: 8,
      top: 8,
      child: isNew ? const NewContentBadge() : const SizedBox.shrink(),
    );

    if (isDetails) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: isSelectionMode ? onToggleSelection : () => onOpen(item),
          onLongPress: isSelectionMode ? onToggleSelection : onStartSelection,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 154,
                child: Stack(
                  children: [thumbnail, newBadgeOverlay, actionOverlay],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.relativePath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!isVerified)
                            const PendingVerificationChip(),
                          _VideoMetaChip(label: mediaCategoryLabel(item)),
                          _VideoMetaChip(label: timestamp),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: isSelectionMode ? onToggleSelection : () => onOpen(item),
        onLongPress: isSelectionMode ? onToggleSelection : onStartSelection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [thumbnail, newBadgeOverlay, actionOverlay]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: Text(
                item.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (!isVerified)
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: PendingVerificationChip(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                '${mediaCategoryLabel(item)} · $timestamp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                item.relativePath,
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

class _VideoEmptyState extends StatelessWidget {
  const _VideoEmptyState({required this.rootPath});

  final String rootPath;

  @override
  Widget build(BuildContext context) {
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
                'No videos found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Import encrypted videos into category folders under $rootPath and refresh.',
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

class _VideoCategoryAccumulator {
  _VideoCategoryAccumulator({required this.key, required this.label});

  final String key;
  final String label;
  final List<DaylySportMediaItem> items = <DaylySportMediaItem>[];
}

String mediaCategoryLabel(DaylySportMediaItem item) {
  return item.categoryLabel ?? sectionLabel(item.section);
}

String sectionLabel(DaylySportMediaSection section) {
  switch (section) {
    case DaylySportMediaSection.reels:
      return 'Reel';
    case DaylySportMediaSection.highlights:
      return 'Highlights';
    case DaylySportMediaSection.news:
      return 'News';
    case DaylySportMediaSection.updates:
      return 'Updates';
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VideoGridMetrics {
  const _VideoGridMetrics(this.maxCrossAxisExtent, this.mainAxisExtent);

  final double maxCrossAxisExtent;
  final double mainAxisExtent;
}

Future<bool?> _confirmDelete(
  BuildContext context, {
  required int count,
  required String label,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(count == 1 ? 'Delete $label?' : 'Delete $count ${label}s?'),
        content: Text(
          count == 1
              ? 'This removes the file from internal storage, clears its cached decrypted copy, and updates offline badges immediately.'
              : 'This removes the selected files from internal storage, clears related cached decrypted copies, and updates offline badges immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

String _deletionSummary(
  OfflineContentDeleteResult result, {
  required String singularLabel,
}) {
  if (result.requestedCount == 0) {
    return 'Nothing was selected.';
  }

  final removed = result.removedOrMissingCount;
  final label = removed == 1 ? singularLabel : '${singularLabel}s';
  if (result.failedCount == 0 && result.cacheWarningCount == 0) {
    return 'Deleted $removed $label.';
  }
  if (result.failedCount == 0) {
    return 'Deleted $removed $label. Some cache files will be retried later.';
  }
  return 'Deleted $removed $label, but ${result.failedCount} item${result.failedCount == 1 ? '' : 's'} could not be removed.';
}
