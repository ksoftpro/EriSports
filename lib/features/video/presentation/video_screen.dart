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
  bool _selectionMode = false;
  bool _isDeleting = false;
  final Set<String> _selectedMediaIds = <String>{};

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);
    final badges = ref.watch(offlineContentBadgeCountsProvider);
    final snapshot = mediaAsync.valueOrNull;
    final allItems =
        snapshot == null
            ? const <DaylySportMediaItem>[]
            : _allVideoItems(snapshot);
    final selectedCount = _selectedMediaIds.length;

    return Scaffold(
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
                isSelectionMode: _selectionMode,
                selectedIds: _selectedMediaIds,
                onToggleSelection: _toggleMediaSelection,
                onStartSelection: _startSelection,
                onDeleteMedia: _deleteSingleMedia,
              ),
              _SectionMediaGrid(
                title: 'News',
                section: snapshot.section(DaylySportMediaSection.news),
                onOpenMedia: _openMediaItem,
                isSelectionMode: _selectionMode,
                selectedIds: _selectedMediaIds,
                onToggleSelection: _toggleMediaSelection,
                onStartSelection: _startSelection,
                onDeleteMedia: _deleteSingleMedia,
              ),
              _SectionMediaGrid(
                title: 'Updates',
                section: snapshot.section(DaylySportMediaSection.updates),
                onOpenMedia: _openMediaItem,
                isSelectionMode: _selectionMode,
                selectedIds: _selectedMediaIds,
                onToggleSelection: _toggleMediaSelection,
                onStartSelection: _startSelection,
                onDeleteMedia: _deleteSingleMedia,
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
    if (_selectionMode || _isDeleting) {
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
    return [
      ...snapshot.section(DaylySportMediaSection.highlights).videoItems,
      ...snapshot.section(DaylySportMediaSection.news).videoItems,
      ...snapshot.section(DaylySportMediaSection.updates).videoItems,
    ];
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
    required this.section,
    required this.onOpenMedia,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onStartSelection,
    required this.onDeleteMedia,
  });

  final String title;
  final DaylySportMediaSectionSnapshot section;
  final ValueChanged<DaylySportMediaItem> onOpenMedia;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final ValueChanged<DaylySportMediaItem> onToggleSelection;
  final ValueChanged<DaylySportMediaItem> onStartSelection;
  final ValueChanged<DaylySportMediaItem> onDeleteMedia;

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
        return _MediaCard(
          item: item,
          onOpen: onOpenMedia,
          isSelectionMode: isSelectionMode,
          isSelected: selectedIds.contains(offlineContentMediaItemId(item)),
          onToggleSelection: () => onToggleSelection(item),
          onStartSelection: () => onStartSelection(item),
          onDelete: () => onDeleteMedia(item),
        );
      },
    );
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
  });

  final DaylySportMediaItem item;
  final ValueChanged<DaylySportMediaItem> onOpen;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onStartSelection;
  final VoidCallback onDelete;

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
        onTap: isSelectionMode ? onToggleSelection : () => onOpen(item),
        onLongPress: isSelectionMode ? onToggleSelection : onStartSelection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
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
                Positioned(
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
                ),
              ],
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
