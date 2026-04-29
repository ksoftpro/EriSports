import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
import 'package:eri_sports/features/reels/presentation/reels_playback_session_store.dart';
import 'package:eri_sports/shared/widgets/offline_content_delete_progress_scope.dart';
import 'package:eri_sports/shared/widgets/offline_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> with RouteAware {
  DateTime? _lastPrewarmScanAt;
  late final PageController _reelsPageController = PageController();
  final ScrollController _reelsRailController = ScrollController();
  ModalRoute<dynamic>? _route;
  bool _routeVisible = true;
  bool _selectionMode = false;
  bool _isDeleting = false;
  int _currentActiveIndex = 0;
  final Set<String> _selectedMediaIds = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) {
      return;
    }

    final observer = ref.read(appRouteObserverProvider);
    if (_route case final PageRoute<dynamic> currentRoute) {
      observer.unsubscribe(this);
      if (_routeVisible != currentRoute.isCurrent && mounted) {
        setState(() {
          _routeVisible = currentRoute.isCurrent;
        });
      }
    }

    _route = route;
    if (route is PageRoute<dynamic>) {
      observer.subscribe(this, route);
      _routeVisible = route.isCurrent;
    } else {
      _routeVisible = true;
    }
  }

  @override
  void dispose() {
    if (_route is PageRoute<dynamic>) {
      ref.read(appRouteObserverProvider).unsubscribe(this);
    }
    _reelsPageController.dispose();
    _reelsRailController.dispose();
    super.dispose();
  }

  @override
  void didPush() => _setRouteVisible(true);

  @override
  void didPopNext() => _setRouteVisible(true);

  @override
  void didPushNext() => _setRouteVisible(false);

  @override
  void didPop() => _setRouteVisible(false);

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(daylySportMediaSnapshotProvider);
    final deleteProgress = ref.watch(offlineContentDeletionProgressProvider);
    final shellIndex = ref.watch(currentShellBranchIndexProvider);
    final lifecycleState = ref.watch(appLifecycleStateProvider);
    final snapshot = mediaAsync.valueOrNull;
    final availableItems =
        snapshot == null
            ? const <DaylySportMediaItem>[]
            : _reelItemsFromSnapshot(snapshot);
    final selectedCount = _selectedMediaIds.length;
    final isScreenActive =
        shellIndex == 3 &&
        _routeVisible &&
        !_selectionMode &&
        !_isDeleting &&
        lifecycleState == AppLifecycleState.resumed;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? 'Select reels ($selectedCount)' : 'Reels'),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _isDeleting ? null : _clearSelection,
              icon: const Icon(Icons.close),
            )
          else if (availableItems.isNotEmpty)
            IconButton(
              tooltip: 'Select reels',
              onPressed: _isDeleting ? null : () => _setSelectionMode(true),
              icon: const Icon(Icons.checklist_rounded),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Delete selected reels',
              onPressed:
                  _isDeleting || selectedCount == 0 || snapshot == null
                      ? null
                      : () => _deleteSelectedReels(snapshot),
              icon: const Icon(Icons.delete_sweep_outlined),
            )
          else if (availableItems.isNotEmpty)
            IconButton(
              tooltip: 'Delete current reel',
              onPressed:
                  _isDeleting
                      ? null
                      : () => _deleteCurrentReel(
                        availableItems[_currentActiveIndex],
                      ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          IconButton(
            tooltip: 'Refresh reels',
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
      ),
      body: OfflineContentDeleteProgressScope(
        progress: deleteProgress,
        child: mediaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, __) => _EmptyReelsState(
                title: 'Unable to load local reels',
                message:
                    'The app could not scan daylySport media folders. Check storage permissions and refresh.',
              ),
          data: (snapshot) {
            final reelsSection = snapshot.section(DaylySportMediaSection.reels);
            final highlightFallback =
                snapshot.section(DaylySportMediaSection.highlights).videoItems;

            final items =
                reelsSection.hasVideoItems
                    ? reelsSection.videoItems
                    : highlightFallback;

            _scheduleEncryptedPrewarm(snapshot, items);

            if (items.isNotEmpty && _currentActiveIndex >= items.length) {
              _currentActiveIndex = items.length - 1;
            }

            if (items.isEmpty) {
              return _EmptyReelsState(
                title: 'No short videos found',
                message:
                    'Add encrypted files in ${reelsSection.scannedDirectories.join(' or ')} to populate reels.',
              );
            }

            if (_selectionMode) {
              return _ReelsSelectionGrid(
                items: items,
                selectedIds: _selectedMediaIds,
                onToggleSelection: _toggleReelSelection,
                onDelete: _deleteSingleReel,
              );
            }

            _syncReelPage(items.length);

            return LayoutBuilder(
              builder: (context, constraints) {
                final railWidth = constraints.maxWidth >= 780 ? 104.0 : 82.0;
                return Row(
                  children: [
                    Expanded(
                      child: ReelsFeed(
                        items: items,
                        pageController: _reelsPageController,
                        isScreenActive: isScreenActive,
                        onActiveIndexChanged: (index) {
                          _currentActiveIndex = index;
                          _scrollReelRail(index);
                        },
                      ),
                    ),
                    SizedBox(
                      width: railWidth,
                      child: _ReelSideRail(
                        items: items,
                        activeIndex: _currentActiveIndex,
                        controller: _reelsRailController,
                        onSelect: _jumpToReel,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _setRouteVisible(bool value) {
    if (_routeVisible == value || !mounted) {
      return;
    }
    setState(() {
      _routeVisible = value;
    });
  }

  void _syncReelPage(int itemCount) {
    if (itemCount <= 0) {
      return;
    }
    final maxIndex = itemCount - 1;
    if (_currentActiveIndex > maxIndex) {
      _currentActiveIndex = maxIndex;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_reelsPageController.hasClients) {
        return;
      }
      final currentPage = _reelsPageController.page?.round() ?? 0;
      if (currentPage != _currentActiveIndex) {
        _reelsPageController.jumpToPage(_currentActiveIndex);
      }
      _scrollReelRail(_currentActiveIndex);
    });
  }

  void _jumpToReel(int index) {
    if (!_reelsPageController.hasClients || _isDeleting) {
      return;
    }
    _reelsPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _scrollReelRail(int index) {
    if (!_reelsRailController.hasClients) {
      return;
    }

    const itemExtent = 96.0;
    final target = (index * itemExtent) - 120;
    final clamped =
        target
            .clamp(0.0, _reelsRailController.position.maxScrollExtent)
            .toDouble();
    _reelsRailController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _scheduleEncryptedPrewarm(
    DaylySportMediaSnapshot snapshot,
    List<DaylySportMediaItem> items,
  ) {
    if (_lastPrewarmScanAt == snapshot.scannedAt) {
      return;
    }
    _lastPrewarmScanAt = snapshot.scannedAt;

    final encryptedVideos = items
        .where((item) => item.isVideo && item.isEncrypted)
        .map((item) => item.file)
        .toList(growable: false);
    if (encryptedVideos.isEmpty) {
      return;
    }

    final service = ref.read(appServicesProvider).encryptedMediaService;
    unawaited(service.prewarmPlayableFiles(encryptedVideos, maxItems: 6));
  }

  List<DaylySportMediaItem> _reelItemsFromSnapshot(
    DaylySportMediaSnapshot snapshot,
  ) {
    final reelsSection = snapshot.section(DaylySportMediaSection.reels);
    final highlightFallback =
        snapshot.section(DaylySportMediaSection.highlights).videoItems;
    return reelsSection.hasVideoItems
        ? reelsSection.videoItems
        : highlightFallback;
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

  void _toggleReelSelection(DaylySportMediaItem item) {
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

  Future<void> _deleteCurrentReel(DaylySportMediaItem item) async {
    final confirmed = await _confirmDelete(context, count: 1, label: 'reel');
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(mediaItems: [item]);
  }

  Future<void> _deleteSingleReel(DaylySportMediaItem item) async {
    final confirmed = await _confirmDelete(context, count: 1, label: 'reel');
    if (confirmed != true || !mounted) {
      return;
    }
    await _runDeletion(mediaItems: [item]);
  }

  Future<void> _deleteSelectedReels(DaylySportMediaSnapshot snapshot) async {
    final selected = _reelItemsFromSnapshot(snapshot)
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
      label: 'reel',
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
      final message = _deletionSummary(result, singularLabel: 'reel');
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

typedef ReelsFeedItemBuilder =
    Widget Function(
      BuildContext context,
      DaylySportMediaItem item,
      bool isActive,
    );

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({
    required this.items,
    this.pageController,
    this.isScreenActive = true,
    this.itemBuilder,
    this.onActiveIndexChanged,
    super.key,
  });

  final List<DaylySportMediaItem> items;
  final PageController? pageController;
  final bool isScreenActive;
  final ReelsFeedItemBuilder? itemBuilder;
  final ValueChanged<int>? onActiveIndexChanged;

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  late final PageController _fallbackPageController = PageController();
  int _activeIndex = 0;

  PageController get _pageController =>
      widget.pageController ?? _fallbackPageController;

  @override
  void didUpdateWidget(covariant ReelsFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) {
      if (_activeIndex != 0) {
        setState(() {
          _activeIndex = 0;
        });
      }
      return;
    }

    final maxIndex = widget.items.length - 1;
    if (_activeIndex > maxIndex) {
      setState(() {
        _activeIndex = maxIndex;
      });
    }
  }

  @override
  void dispose() {
    if (widget.pageController == null) {
      _fallbackPageController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.items.length,
      onPageChanged: (index) {
        if (_activeIndex == index) {
          return;
        }
        setState(() {
          _activeIndex = index;
        });
        widget.onActiveIndexChanged?.call(index);
      },
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isActive = widget.isScreenActive && index == _activeIndex;
        final builder = widget.itemBuilder;
        if (builder != null) {
          return builder(context, item, isActive);
        }
        return _ReelCard(item: item, isActive: isActive);
      },
    );
  }
}

class _ReelSideRail extends StatelessWidget {
  const _ReelSideRail({
    required this.items,
    required this.activeIndex,
    required this.controller,
    required this.onSelect,
  });

  final List<DaylySportMediaItem> items;
  final int activeIndex;
  final ScrollController controller;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 10, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isActive = index == activeIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? scheme.primaryContainer.withValues(alpha: 0.75)
                          : scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? scheme.primary : scheme.outlineVariant,
                    width: isActive ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 9 / 16,
                      child: OfflineVideoThumbnail(
                        item: item,
                        maxDimension: 240,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${index + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            isActive
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReelsSelectionGrid extends StatelessWidget {
  const _ReelsSelectionGrid({
    required this.items,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onDelete,
  });

  final List<DaylySportMediaItem> items;
  final Set<String> selectedIds;
  final ValueChanged<DaylySportMediaItem> onToggleSelection;
  final ValueChanged<DaylySportMediaItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 210,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(
          offlineContentMediaItemId(item),
        );
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onToggleSelection(item),
            onLongPress: () => onToggleSelection(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E232D), Color(0xFF0E1118)],
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 72,
                    color: Colors.white70,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.relativePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    tooltip: 'Delete reel',
                    onPressed: () => onDelete(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.item, required this.isActive});

  final DaylySportMediaItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _InlineReelVideo(item: item, isActive: isActive),
              IgnorePointer(
                child: DecoratedBox(
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
      ),
    );
  }
}

class _InlineReelVideo extends ConsumerStatefulWidget {
  const _InlineReelVideo({required this.item, required this.isActive});

  final DaylySportMediaItem item;
  final bool isActive;

  @override
  ConsumerState<_InlineReelVideo> createState() => _InlineReelVideoState();
}

class _InlineReelVideoState extends ConsumerState<_InlineReelVideo> {
  late final AppServices _services = ref.read(appServicesProvider);
  VideoPlayerController? _controller;
  bool _isPreparing = false;
  String? _errorMessage;
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensurePrepared();
    }
  }

  @override
  void didUpdateWidget(covariant _InlineReelVideo oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.item.file.path != widget.item.file.path) {
      _disposeController(item: oldWidget.item, persistPosition: true);
      _errorMessage = null;
      if (widget.isActive) {
        _ensurePrepared();
      }
      return;
    }

    if (!oldWidget.isActive && widget.isActive) {
      unawaited(
        ref
            .read(offlineContentRefreshControllerProvider.notifier)
            .markMediaItemSeen(widget.item),
      );
      _ensurePrepared();
      unawaited(_playIfReady());
    } else if (oldWidget.isActive && !widget.isActive) {
      unawaited(_pauseAndPersistIfReady(item: oldWidget.item));
    }
  }

  @override
  void dispose() {
    _disposeController(item: widget.item, persistPosition: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;
    final isPlaying = isReady && controller.value.isPlaying;
    final duration = isReady ? controller.value.duration : Duration.zero;
    final playbackPosition =
        isReady ? controller.value.position : Duration.zero;
    final displayPosition =
        _isScrubbing ? _scrubPosition : playbackPosition;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isReady ? _togglePlayback : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isReady)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E232D), Color(0xFF0E1118)],
                ),
              ),
              child: SizedBox.expand(),
            ),
          if (_isPreparing)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Unable to play this reel.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ),
            )
          else if (!isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 84,
                color: Colors.white70,
              ),
            ),
          if (isReady)
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: _sliderValue(
                            position: displayPosition,
                            duration: duration,
                          ),
                          min: 0,
                          max: duration.inMilliseconds > 0
                              ? duration.inMilliseconds.toDouble()
                              : 1,
                          onChanged: _handleScrubChanged,
                          onChangeStart: _handleScrubStart,
                          onChangeEnd: _handleScrubEnd,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _formatDuration(displayPosition),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(duration),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ensurePrepared() async {
    if (_controller != null || _isPreparing || !widget.item.isVideo) {
      return;
    }

    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      if (widget.isActive) {
        unawaited(
          ref
              .read(offlineContentRefreshControllerProvider.notifier)
              .markMediaItemSeen(widget.item),
        );
      }
      final playable = await _services.encryptedMediaService.resolvePlayableFile(
        widget.item.file,
      );
      final controller = VideoPlayerController.file(File(playable.file.path));
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_handleControllerUpdated);
      final resumePosition = await _services.videoResumeService.readPosition(
        videoKey: reelPlaybackItemKey(widget.item),
        totalDuration: controller.value.duration,
      );
      if (resumePosition != null) {
        await controller.seekTo(resumePosition);
      }
      if (widget.isActive) {
        await controller.play();
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _controller;
      setState(() {
        _controller = controller;
        _isPreparing = false;
        _scrubPosition = controller.value.position;
      });
      if (previousController != null) {
        unawaited(_pausePersistAndDispose(previousController, widget.item));
      }

      if (!widget.isActive) {
        await controller.pause();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _errorMessage = 'Unable to play this reel.';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      await _saveCurrentPosition(controller, widget.item);
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleControllerUpdated() {
    if (!mounted || _isScrubbing) {
      return;
    }
    setState(() {});
  }

  void _handleScrubStart(double value) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() {
      _isScrubbing = true;
      _scrubPosition = Duration(milliseconds: value.round());
    });
  }

  void _handleScrubChanged(double value) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    setState(() {
      _isScrubbing = true;
      _scrubPosition = Duration(milliseconds: value.round());
    });
  }

  Future<void> _handleScrubEnd(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final target = Duration(milliseconds: value.round());
    setState(() {
      _scrubPosition = target;
    });
    await controller.seekTo(target);
    if (!mounted) {
      return;
    }
    setState(() {
      _isScrubbing = false;
      _scrubPosition = controller.value.position;
    });
  }

  Future<void> _playIfReady() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isPlaying) {
      return;
    }
    await controller.play();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pauseAndPersistIfReady({required DaylySportMediaItem item}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    }
    await _saveCurrentPosition(controller, item);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCurrentPosition(
    VideoPlayerController controller,
    DaylySportMediaItem item,
  ) {
    if (!item.isVideo || !controller.value.isInitialized) {
      return Future<void>.value();
    }

    return _services.videoResumeService.savePosition(
      videoKey: reelPlaybackItemKey(item),
      position: controller.value.position,
      totalDuration: controller.value.duration,
    );
  }

  Future<void> _pausePersistAndDispose(
    VideoPlayerController controller,
    DaylySportMediaItem item,
  ) async {
    controller.removeListener(_handleControllerUpdated);
    if (controller.value.isInitialized && controller.value.isPlaying) {
      await controller.pause();
    }
    await _saveCurrentPosition(controller, item);
    await controller.dispose();
  }

  void _disposeController({
    required DaylySportMediaItem item,
    required bool persistPosition,
  }) {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (persistPosition) {
        unawaited(_pausePersistAndDispose(controller, item));
      } else {
        unawaited(controller.dispose());
      }
    }
  }

  double _sliderValue({
    required Duration position,
    required Duration duration,
  }) {
    final max =
        duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1;
    return position.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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
              ? 'This stops playback, removes the source video from internal storage, clears its cached decrypted copy, and updates offline badges immediately.'
              : 'This stops playback, removes the selected source videos from internal storage, clears related cached decrypted copies, and updates offline badges immediately.',
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
