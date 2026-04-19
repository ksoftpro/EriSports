import 'dart:async';

import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:eri_sports/features/news/presentation/offline_news_providers.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/shared/widgets/new_content_badge.dart';
import 'package:eri_sports/shared/widgets/offline_content_delete_progress_scope.dart';
import 'package:eri_sports/shared/widgets/secure_file_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OfflineNewsScreen extends ConsumerStatefulWidget {
  const OfflineNewsScreen({super.key});

  @override
  ConsumerState<OfflineNewsScreen> createState() => _OfflineNewsScreenState();
}

class _OfflineNewsScreenState extends ConsumerState<OfflineNewsScreen> {
  late final PageController _pageController;
  final ScrollController _thumbnailScrollController = ScrollController();
  final Set<String> _selectedNewsIds = <String>{};
  int _currentIndex = 0;
  bool _selectionMode = false;
  bool _isDeleting = false;
  DateTime? _lastSortedSnapshotAt;
  List<OfflineNewsMediaItem> _sortedImages = const <OfflineNewsMediaItem>[];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() {
    return ref.read(offlineNewsGalleryProvider.notifier).refreshGallery();
  }

  @override
  Widget build(BuildContext context) {
    final galleryAsync = ref.watch(offlineNewsGalleryProvider);
    final badges = ref.watch(offlineContentBadgeCountsProvider);
    final deleteProgress = ref.watch(offlineContentDeletionProgressProvider);
    final seenItemIds = ref.watch(offlineSeenItemIdsProvider);
    final snapshot = galleryAsync.valueOrNull;
    final displayedImages =
      snapshot == null ? const <OfflineNewsMediaItem>[] : _sortedImagesForSnapshot(snapshot);
    final selectedCount = _selectedNewsIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectionMode ? 'Select news ($selectedCount)' : 'Offline News',
            ),
            if (badges.newsImages > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badges.newsImages > 99 ? '99+' : '${badges.newsImages}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onError,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (displayedImages.isNotEmpty && !_selectionMode)
            IconButton(
              tooltip: 'Select news images',
              onPressed: _isDeleting ? null : () => _setSelectionMode(true),
              icon: const Icon(Icons.checklist_rounded),
            ),
          if (_selectionMode && displayedImages.isNotEmpty)
            IconButton(
              tooltip: 'Toggle current image',
              onPressed:
                  _isDeleting
                      ? null
                      : () => _toggleNewsSelection(displayedImages[_currentIndex]),
              icon: Icon(
                _selectedNewsIds.contains(
                      offlineContentNewsItemId(displayedImages[_currentIndex]),
                    )
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _isDeleting ? null : _clearSelection,
              icon: const Icon(Icons.close),
            )
          else if (displayedImages.isNotEmpty)
            IconButton(
              tooltip: 'Delete current image',
              onPressed:
                  _isDeleting
                      ? null
                      : () => _deleteCurrentNews(displayedImages[_currentIndex]),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Delete selected images',
              onPressed:
                  _isDeleting || _selectedNewsIds.isEmpty || snapshot == null
                      ? null
                      : () => _deleteSelectedNews(snapshot),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            tooltip: 'Refresh encrypted news',
            onPressed: _isDeleting ? null : _onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: OfflineContentDeleteProgressScope(
          progress: deleteProgress,
          child: galleryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, stackTrace) => _OfflineNewsEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Unable to load offline news',
                  message:
                      'The app could not scan daylySport/news right now. Please check storage permissions and try again.',
                  ctaLabel: 'Retry',
                  onPressed: _onRefresh,
                ),
            data: (snapshot) {
              final images = _sortedImagesForSnapshot(snapshot);
              unawaited(
                ref
                    .read(offlineContentRefreshControllerProvider.notifier)
                    .markNewsItemsSeen(images.take(1)),
              );
              if (!snapshot.newsDirectoryExists) {
                return _OfflineNewsEmptyState(
                  icon: Icons.folder_off,
                  title: 'No news folder found',
                  message:
                      'Create this folder and add encrypted news images: ${snapshot.newsDirectory.path}',
                  ctaLabel: 'Refresh',
                  onPressed: _onRefresh,
                );
              }

              if (!snapshot.hasImages) {
                final details = StringBuffer(
                  'No encrypted news images were found in ${snapshot.newsDirectory.path}.',
                );
                if (snapshot.skippedUnsupportedCount > 0) {
                  details.write(
                    '\n\nSkipped non-encrypted or unsupported files: ${snapshot.skippedUnsupportedCount}.',
                  );
                }
                details.write(
                  '\nSupported encrypted formats: ${snapshot.supportedFormats.join(', ')}',
                );

                return _OfflineNewsEmptyState(
                  icon: Icons.image_not_supported_outlined,
                  title: 'No encrypted news images yet',
                  message: details.toString(),
                  ctaLabel: 'Refresh',
                  onPressed: _onRefresh,
                );
              }

              final maxIndex = images.length - 1;
              if (_currentIndex > maxIndex) {
                _currentIndex = maxIndex;
              }

              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          unawaited(
                            ref
                                .read(
                                  offlineContentRefreshControllerProvider
                                      .notifier,
                                )
                                .markNewsItemSeen(images[index]),
                          );
                          setState(() {
                            _currentIndex = index;
                          });
                          _scrollThumbnailStrip(index);
                        },
                        itemBuilder: (context, index) {
                          final media = images[index];
                          return _OfflineNewsPage(media: media);
                        },
                      ),
                    ),
                    _OfflineNewsFooter(
                      currentIndex: _currentIndex,
                      total: images.length,
                      unreadableCount: snapshot.unreadableCount,
                      skippedUnsupportedCount: snapshot.skippedUnsupportedCount,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 84,
                      child: ListView.builder(
                        controller: _thumbnailScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final media = images[index];
                          final selected = index == _currentIndex;
                          final isNew = !isOfflineNewsItemSeen(media, seenItemIds);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () {
                                if (_selectionMode) {
                                  _toggleNewsSelection(media);
                                  return;
                                }
                                _pageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                              onLongPress: () {
                                if (_selectionMode) {
                                  _toggleNewsSelection(media);
                                  return;
                                }
                                _startSelection(media);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    width: selected ? 2 : 1,
                                    color:
                                        _selectedNewsIds.contains(
                                              offlineContentNewsItemId(media),
                                            )
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.error
                                            : selected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    SecureFileImage(
                                      sourceFile: media.file,
                                      fit: BoxFit.cover,
                                      loadingWidget: _ThumbnailLoadingState(
                                        isSelected: selected,
                                      ),
                                      errorBuilder:
                                          (context, error, stackTrace) => Container(
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                    ),
                                    if (isNew)
                                      const Positioned(
                                        left: 4,
                                        top: 4,
                                        child: NewContentBadge(),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<OfflineNewsMediaItem> _sortedImagesForSnapshot(
    OfflineNewsGallerySnapshot snapshot,
  ) {
    if (_lastSortedSnapshotAt == snapshot.scannedAt) {
      return _sortedImages;
    }

    _sortedImages = sortOfflineNewsItemsForDisplay(
      snapshot.images,
      ref.read(offlineSeenItemIdsProvider),
    );
    _lastSortedSnapshotAt = snapshot.scannedAt;
    return _sortedImages;
  }

  void _scrollThumbnailStrip(int index) {
    if (!_thumbnailScrollController.hasClients) {
      return;
    }

    const itemWidth = 76.0;
    final target = (index * itemWidth) - 96;
    final clamped =
        target
            .clamp(0.0, _thumbnailScrollController.position.maxScrollExtent)
            .toDouble();

    _thumbnailScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _setSelectionMode(bool value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = value;
      if (!value) {
        _selectedNewsIds.clear();
      }
    });
  }

  void _clearSelection() {
    _setSelectionMode(false);
  }

  void _startSelection(OfflineNewsMediaItem item) {
    if (_isDeleting) {
      return;
    }
    setState(() {
      _selectionMode = true;
      _selectedNewsIds
        ..clear()
        ..add(offlineContentNewsItemId(item));
    });
  }

  void _toggleNewsSelection(OfflineNewsMediaItem item) {
    if (_isDeleting) {
      return;
    }
    final itemId = offlineContentNewsItemId(item);
    setState(() {
      _selectionMode = true;
      if (!_selectedNewsIds.add(itemId)) {
        _selectedNewsIds.remove(itemId);
      }
      if (_selectedNewsIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteCurrentNews(OfflineNewsMediaItem item) async {
    final confirmed = await _confirmDelete(
      context,
      count: 1,
      label: 'news image',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(newsItems: [item]);
  }

  Future<void> _deleteSelectedNews(OfflineNewsGallerySnapshot snapshot) async {
    final selected = _sortedImagesForSnapshot(snapshot)
        .where(
          (item) => _selectedNewsIds.contains(offlineContentNewsItemId(item)),
        )
        .toList(growable: false);
    if (selected.isEmpty) {
      _clearSelection();
      return;
    }

    final confirmed = await _confirmDelete(
      context,
      count: selected.length,
      label: 'news image',
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(newsItems: selected, clearSelectionAfter: true);
  }

  Future<void> _runDeletion({
    required List<OfflineNewsMediaItem> newsItems,
    bool clearSelectionAfter = false,
  }) async {
    if (newsItems.isEmpty) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final result = await ref
          .read(offlineContentRefreshControllerProvider.notifier)
          .deleteItems(newsItems: newsItems);
      if (!mounted) {
        return;
      }
      if (clearSelectionAfter) {
        _clearSelection();
      }
      final message = _deletionSummary(result, singularLabel: 'news image');
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
              ? 'This removes the source image from internal storage, clears its cached decrypted copy, and updates offline badges immediately.'
              : 'This removes the selected source images from internal storage, clears related cached decrypted copies, and updates offline badges immediately.',
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

class _OfflineNewsPage extends StatelessWidget {
  const _OfflineNewsPage({required this.media});

  final OfflineNewsMediaItem media;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: colorScheme.surfaceContainerLowest,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: SecureFileImage(
                      sourceFile: media.file,
                      width: constraints.maxWidth,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      loadingWidget: const _NewsImageLoadingState(),
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const _CorruptedImageState(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NewsImageLoadingState extends StatelessWidget {
  const _NewsImageLoadingState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Decrypting image...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Preparing a cached copy for smoother next loads.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailLoadingState extends StatelessWidget {
  const _ThumbnailLoadingState({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color:
          isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.45)
              : colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color:
                isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OfflineNewsFooter extends StatelessWidget {
  const _OfflineNewsFooter({
    required this.currentIndex,
    required this.total,
    required this.unreadableCount,
    required this.skippedUnsupportedCount,
  });

  final int currentIndex;
  final int total;
  final int unreadableCount;
  final int skippedUnsupportedCount;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${currentIndex + 1} / $total', style: style),
              const Spacer(),
              if (skippedUnsupportedCount > 0)
                Text('Skipped: $skippedUnsupportedCount', style: style),
              if (skippedUnsupportedCount > 0 && unreadableCount > 0)
                const SizedBox(width: 10),
              if (unreadableCount > 0)
                Text('Unreadable: $unreadableCount', style: style),
            ],
          ),
        ],
      ),
    );
  }
}

class _CorruptedImageState extends StatelessWidget {
  const _CorruptedImageState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to render image',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNewsEmptyState extends StatelessWidget {
  const _OfflineNewsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.refresh),
                label: Text(ctaLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
