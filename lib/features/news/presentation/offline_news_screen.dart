import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:eri_sports/features/news/presentation/offline_news_providers.dart';
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
  int _currentIndex = 0;

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline News'),
        actions: [
          IconButton(
            tooltip: 'Refresh encrypted news',
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
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

            final maxIndex = snapshot.images.length - 1;
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
                      itemCount: snapshot.images.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        _scrollThumbnailStrip(index);
                      },
                      itemBuilder: (context, index) {
                        final media = snapshot.images[index];
                        return _OfflineNewsPage(media: media);
                      },
                    ),
                  ),
                  _OfflineNewsFooter(
                    currentIndex: _currentIndex,
                    total: snapshot.images.length,
                    currentFileName: snapshot.images[_currentIndex].fileName,
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
                      itemCount: snapshot.images.length,
                      itemBuilder: (context, index) {
                        final media = snapshot.images[index];
                        final selected = index == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 68,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  width: selected ? 2 : 1,
                                  color:
                                      selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SecureFileImage(
                                sourceFile: media.file,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
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
    );
  }

  void _scrollThumbnailStrip(int index) {
    if (!_thumbnailScrollController.hasClients) {
      return;
    }

    const itemWidth = 76.0;
    final target = (index * itemWidth) - 96;
    final clamped = target
        .clamp(0.0, _thumbnailScrollController.position.maxScrollExtent)
        .toDouble();

    _thumbnailScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }
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
                      errorBuilder:
                          (context, error, stackTrace) => _CorruptedImageState(
                            fileName: media.fileName,
                          ),
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

class _OfflineNewsFooter extends StatelessWidget {
  const _OfflineNewsFooter({
    required this.currentIndex,
    required this.total,
    required this.currentFileName,
    required this.unreadableCount,
    required this.skippedUnsupportedCount,
  });

  final int currentIndex;
  final int total;
  final String currentFileName;
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
          const SizedBox(height: 4),
          Text(
            currentFileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _CorruptedImageState extends StatelessWidget {
  const _CorruptedImageState({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(
              'Unable to render image',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
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
