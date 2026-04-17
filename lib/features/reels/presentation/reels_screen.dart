import 'dart:async';
import 'dart:io';

import 'package:eri_sports/app/app.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:eri_sports/app/navigation/app_shell.dart';
import 'package:eri_sports/app/navigation/router.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:eri_sports/features/media/presentation/daylysport_media_providers.dart';
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
  ModalRoute<dynamic>? _route;
  bool _routeVisible = true;

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
    final shellIndex = ref.watch(currentShellBranchIndexProvider);
    final lifecycleState = ref.watch(appLifecycleStateProvider);
    final isScreenActive =
        shellIndex == 3 &&
        _routeVisible &&
        lifecycleState == AppLifecycleState.resumed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reels'),
        actions: [
          IconButton(
            tooltip: 'Refresh reels',
            onPressed:
                () =>
                    ref
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
          final highlightFallback =
              snapshot.section(DaylySportMediaSection.highlights).videoItems;

          final items =
              reelsSection.hasVideoItems
                  ? reelsSection.videoItems
                  : highlightFallback;

          _scheduleEncryptedPrewarm(snapshot, items);

          if (items.isEmpty) {
            return _EmptyReelsState(
              title: 'No short videos found',
              message:
                  'Add encrypted files in ${reelsSection.scannedDirectories.join(' or ')} to populate reels.',
            );
          }

          return ReelsFeed(items: items, isScreenActive: isScreenActive);
        },
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
    this.isScreenActive = true,
    this.itemBuilder,
    super.key,
  });

  final List<DaylySportMediaItem> items;
  final bool isScreenActive;
  final ReelsFeedItemBuilder? itemBuilder;

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  late final PageController _pageController = PageController();
  int _activeIndex = 0;

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
    _pageController.dispose();
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
  VideoPlayerController? _controller;
  bool _isPreparing = false;
  String? _errorMessage;

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
      _disposeController();
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
      unawaited(_pauseIfReady());
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;
    final isPlaying = isReady && controller.value.isPlaying;

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
      final services = ref.read(appServicesProvider);
      final playable = await services.encryptedMediaService.resolvePlayableFile(
        widget.item.file,
      );
      final controller = VideoPlayerController.file(File(playable.file.path));
      await controller.initialize();
      await controller.setLooping(true);
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
      });
      if (previousController != null) {
        unawaited(previousController.dispose());
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
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _pauseIfReady() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    await controller.pause();
    if (mounted) {
      setState(() {});
    }
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
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
