import 'dart:io';
import 'dart:isolate';

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SecureContentScreen extends ConsumerStatefulWidget {
  const SecureContentScreen({super.key});

  @override
  ConsumerState<SecureContentScreen> createState() =>
      _SecureContentScreenState();
}

class _SecureContentScreenState extends ConsumerState<SecureContentScreen> {
  SecureContentInventory? _inventory;
  String? _errorMessage;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isRefreshing = false;
  bool _isWarmingCaches = false;
  bool _isClearingCaches = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refreshInventory);
  }

  Future<void> _refreshInventory() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final services = ref.read(appServicesProvider);
      final directory =
          await services.daylySportLocator.getOrCreateDaylySportDirectory();
      final inventory = await scanSecureContentInventoryInIsolate(
        directory.path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _inventory = inventory;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '$error';
        _isRefreshing = false;
      });
    }
  }

  Future<void> _warmCaches() async {
    if (_isWarmingCaches || _isClearingCaches) {
      return;
    }

    setState(() {
      _isWarmingCaches = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      await ref.read(appServicesProvider).secureContentCoordinator.warmUp();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Secure runtime caches are ready for JSON, images, and video.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Cache warm-up failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isWarmingCaches = false;
        });
      }
    }
  }

  Future<void> _clearCaches() async {
    if (_isWarmingCaches || _isClearingCaches) {
      return;
    }

    setState(() {
      _isClearingCaches = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      await ref
          .read(appServicesProvider)
          .secureContentCoordinator
          .clearCaches();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage =
            'Decrypted cache files were removed. Encrypted source files were not changed.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Cache clear failed: $error';
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCaches = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inventory = _inventory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Content'),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshInventory,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rescan offline content',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshInventory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encrypted offline runtime',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage encrypted daylySport JSON, images, and video without touching the original source bundle.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [
                        _StatChip(label: 'JSON', value: '.esj'),
                        _StatChip(label: 'Images', value: '.esi'),
                        _StatChip(label: 'Video', value: '.esv'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _isWarmingCaches || _isClearingCaches
                                  ? null
                                  : _warmCaches,
                          icon: const Icon(Icons.bolt_rounded),
                          label: Text(
                            _isWarmingCaches
                                ? 'Warming caches...'
                                : 'Warm secure caches',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _isWarmingCaches || _isClearingCaches
                                  ? null
                                  : _clearCaches,
                          icon: const Icon(Icons.cleaning_services_rounded),
                          label: Text(
                            _isClearingCaches
                                ? 'Clearing caches...'
                                : 'Clear decrypted caches',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/sync'),
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Open sync tools'),
                        ),
                      ],
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _statusIsError ? scheme.error : scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_isRefreshing && inventory == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to inspect secure content',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    ],
                  ),
                ),
              )
            else if (inventory != null) ...[
              _InventoryOverviewCard(inventory: inventory),
              const SizedBox(height: 14),
              _InventoryBreakdownCard(inventory: inventory),
              const SizedBox(height: 14),
              _InventorySamplesCard(inventory: inventory),
            ],
          ],
        ),
      ),
    );
  }
}

Future<SecureContentInventory> scanSecureContentInventoryInIsolate(
  String rootPath,
) {
  return Isolate.run(() => scanSecureContentInventory(rootPath));
}

class SecureContentInventory {
  const SecureContentInventory({
    required this.rootPath,
    required this.scannedAtUtc,
    required this.totalFiles,
    required this.otherFiles,
    required this.plainJsonFiles,
    required this.encryptedJsonFiles,
    required this.plainImageFiles,
    required this.encryptedImageFiles,
    required this.plainVideoFiles,
    required this.encryptedVideoFiles,
    required this.sampleEncryptedPaths,
    required this.samplePlainPaths,
  });

  final String rootPath;
  final DateTime scannedAtUtc;
  final int totalFiles;
  final int otherFiles;
  final int plainJsonFiles;
  final int encryptedJsonFiles;
  final int plainImageFiles;
  final int encryptedImageFiles;
  final int plainVideoFiles;
  final int encryptedVideoFiles;
  final List<String> sampleEncryptedPaths;
  final List<String> samplePlainPaths;

  int get supportedFiles =>
      plainJsonFiles +
      encryptedJsonFiles +
      plainImageFiles +
      encryptedImageFiles +
      plainVideoFiles +
      encryptedVideoFiles;

  int get encryptedFiles =>
      encryptedJsonFiles + encryptedImageFiles + encryptedVideoFiles;

  int get plainFiles => plainJsonFiles + plainImageFiles + plainVideoFiles;

  int get encryptedCoveragePercent {
    if (supportedFiles == 0) {
      return 0;
    }
    return ((encryptedFiles / supportedFiles) * 100).round();
  }
}

SecureContentInventory scanSecureContentInventory(String rootPath) {
  final resolver = const EncryptedFileResolver();
  final rootDirectory = Directory(rootPath);
  var totalFiles = 0;
  var otherFiles = 0;
  var plainJsonFiles = 0;
  var encryptedJsonFiles = 0;
  var plainImageFiles = 0;
  var encryptedImageFiles = 0;
  var plainVideoFiles = 0;
  var encryptedVideoFiles = 0;
  final sampleEncryptedPaths = <String>[];
  final samplePlainPaths = <String>[];

  if (rootDirectory.existsSync()) {
    for (final entity in rootDirectory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      totalFiles += 1;

      SecureContentDescriptor descriptor;
      try {
        descriptor = resolver.describePath(entity.path);
      } catch (_) {
        otherFiles += 1;
        continue;
      }

      switch (descriptor.kind) {
        case SecureContentKind.json:
          if (descriptor.isEncrypted) {
            encryptedJsonFiles += 1;
          } else {
            plainJsonFiles += 1;
          }
        case SecureContentKind.image:
          if (descriptor.isEncrypted) {
            encryptedImageFiles += 1;
          } else {
            plainImageFiles += 1;
          }
        case SecureContentKind.video:
          if (descriptor.isEncrypted) {
            encryptedVideoFiles += 1;
          } else {
            plainVideoFiles += 1;
          }
        case SecureContentKind.other:
          otherFiles += 1;
      }

      final relativePath = resolver.logicalRelativePath(
        entity.path,
        fromDirectory: rootPath,
      );
      if (descriptor.isEncrypted && sampleEncryptedPaths.length < 6) {
        sampleEncryptedPaths.add(relativePath);
      } else if (!descriptor.isEncrypted &&
          descriptor.kind != SecureContentKind.other &&
          samplePlainPaths.length < 6) {
        samplePlainPaths.add(relativePath);
      }
    }
  }

  return SecureContentInventory(
    rootPath: rootPath,
    scannedAtUtc: DateTime.now().toUtc(),
    totalFiles: totalFiles,
    otherFiles: otherFiles,
    plainJsonFiles: plainJsonFiles,
    encryptedJsonFiles: encryptedJsonFiles,
    plainImageFiles: plainImageFiles,
    encryptedImageFiles: encryptedImageFiles,
    plainVideoFiles: plainVideoFiles,
    encryptedVideoFiles: encryptedVideoFiles,
    sampleEncryptedPaths: sampleEncryptedPaths,
    samplePlainPaths: samplePlainPaths,
  );
}

class _InventoryOverviewCard extends StatelessWidget {
  const _InventoryOverviewCard({required this.inventory});

  final SecureContentInventory inventory;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text('Source folder: ${inventory.rootPath}'),
            Text(
              'Last scanned: ${formatter.format(inventory.scannedAtUtc.toLocal())}',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  label: 'Supported files',
                  value: '${inventory.supportedFiles}',
                ),
                _MetricTile(
                  label: 'Encrypted files',
                  value: '${inventory.encryptedFiles}',
                ),
                _MetricTile(
                  label: 'Plain files',
                  value: '${inventory.plainFiles}',
                ),
                _MetricTile(
                  label: 'Coverage',
                  value: '${inventory.encryptedCoveragePercent}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              inventory.plainFiles == 0
                  ? 'All detected JSON, image, and video files are encrypted.'
                  : 'Plain supported files are still present. They remain readable, but they are not protected at rest.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryBreakdownCard extends StatelessWidget {
  const _InventoryBreakdownCard({required this.inventory});

  final SecureContentInventory inventory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Encrypted file breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _BreakdownRow(
              label: 'JSON',
              encryptedCount: inventory.encryptedJsonFiles,
              plainCount: inventory.plainJsonFiles,
            ),
            const SizedBox(height: 10),
            _BreakdownRow(
              label: 'Images',
              encryptedCount: inventory.encryptedImageFiles,
              plainCount: inventory.plainImageFiles,
            ),
            const SizedBox(height: 10),
            _BreakdownRow(
              label: 'Video',
              encryptedCount: inventory.encryptedVideoFiles,
              plainCount: inventory.plainVideoFiles,
            ),
            const SizedBox(height: 10),
            Text('Other files: ${inventory.otherFiles}'),
          ],
        ),
      ),
    );
  }
}

class _InventorySamplesCard extends StatelessWidget {
  const _InventorySamplesCard({required this.inventory});

  final SecureContentInventory inventory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detected files',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _PathPreviewList(
              title: 'Encrypted samples',
              emptyLabel:
                  'No encrypted JSON, image, or video files were found.',
              paths: inventory.sampleEncryptedPaths,
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
            _PathPreviewList(
              title: 'Plain samples',
              emptyLabel: 'No plain supported files were found.',
              paths: inventory.samplePlainPaths,
              icon: Icons.folder_open_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.encryptedCount,
    required this.plainCount,
  });

  final String label;
  final int encryptedCount;
  final int plainCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text('Encrypted $encryptedCount'),
        const SizedBox(width: 12),
        Text('Plain $plainCount'),
      ],
    );
  }
}

class _PathPreviewList extends StatelessWidget {
  const _PathPreviewList({
    required this.title,
    required this.emptyLabel,
    required this.paths,
    required this.icon,
  });

  final String title;
  final String emptyLabel;
  final List<String> paths;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (paths.isEmpty)
          Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
        else
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      path,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
