import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class SecureContentScreen extends ConsumerStatefulWidget {
  const SecureContentScreen({super.key});

  @override
  ConsumerState<SecureContentScreen> createState() =>
      _SecureContentScreenState();
}

class _SecureContentScreenState extends ConsumerState<SecureContentScreen> {
  static const int _bulkRemoveConfirmationThreshold = 5;
  static const List<String> _allowedSourceExtensions = <String>[
    'json',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'mp4',
    'mov',
    'm4v',
    'webm',
    'mkv',
    'avi',
    '3gp',
  ];

  SecureContentInventory? _inventory;
  String? _errorMessage;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isRefreshing = false;
  bool _isWarmingCaches = false;
  bool _isClearingCaches = false;
  bool _isPickingSources = false;
  bool _isEncrypting = false;
  bool _overwriteExisting = true;
  String? _selectedSourceRoot;
  int _nextSelectionId = 0;
  late final SecureContentEncryptionJobManager _jobManager;
  StreamSubscription<SecureContentEncryptionJobSnapshot>? _jobSubscription;
  SecureContentEncryptionJobSnapshot _jobSnapshot =
      const SecureContentEncryptionJobSnapshot.idle();
  final TextEditingController _jsonDestinationController =
      TextEditingController(text: 'json');
  final TextEditingController _imageDestinationController =
      TextEditingController(text: 'news');
  final TextEditingController _videoDestinationController =
      TextEditingController(text: 'reels');
  final List<_PendingSecureSource> _selectedSources = <_PendingSecureSource>[];

  @override
  void initState() {
    super.initState();
    _jobManager = ref.read(appServicesProvider).secureContentEncryptionJobManager;
    _jobSnapshot = _jobManager.snapshot;
    _isEncrypting = _jobSnapshot.isRunning;
    _jobSubscription = _jobManager.stream.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _jobSnapshot = snapshot;
        _isEncrypting = snapshot.isRunning;
      });
    });
    Future<void>.microtask(_refreshInventory);
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _jsonDestinationController.dispose();
    _imageDestinationController.dispose();
    _videoDestinationController.dispose();
    super.dispose();
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

  Future<void> _pickFiles() async {
    if (_isPickingSources || _isEncrypting) {
      return;
    }

    setState(() {
      _isPickingSources = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedSourceExtensions,
        dialogTitle: 'Select JSON, image, or video files',
      );

      if (!mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        setState(() {
          _statusMessage = 'File selection canceled.';
          _isPickingSources = false;
        });
        return;
      }

      final selected = <_PendingSecureSource>[];
      for (final item in result.files) {
        final path = item.path;
        if (path == null || path.trim().isEmpty) {
          continue;
        }
        final source = _buildPendingSource(path, p.basename(path));
        if (source != null) {
          selected.add(source);
        }
      }

      setState(() {
        _selectedSourceRoot = null;
        _selectedSources
          ..clear()
          ..addAll(selected);
        _statusMessage =
            selected.isEmpty
                ? 'No supported plain JSON, image, or video files were selected.'
                : 'Selected ${selected.length} source files for encryption.';
        _statusIsError = false;
        _isPickingSources = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to pick files: $error';
        _statusIsError = true;
        _isPickingSources = false;
      });
    }
  }

  Future<void> _pickFolder() async {
    if (_isPickingSources || _isEncrypting) {
      return;
    }

    setState(() {
      _isPickingSources = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select source folder to encrypt',
      );

      if (!mounted) {
        return;
      }

      if (folderPath == null || folderPath.trim().isEmpty) {
        setState(() {
          _statusMessage = 'Folder selection canceled.';
          _isPickingSources = false;
        });
        return;
      }

      final filePaths = await collectEncryptableSourceFilesInIsolate(folderPath);
      final selected = <_PendingSecureSource>[];
      for (final path in filePaths) {
        final relativePath = p.relative(path, from: folderPath);
        final source = _buildPendingSource(path, relativePath);
        if (source != null) {
          selected.add(source);
        }
      }

      setState(() {
        _selectedSourceRoot = folderPath;
        _selectedSources
          ..clear()
          ..addAll(selected);
        _statusMessage =
            selected.isEmpty
                ? 'No supported plain JSON, image, or video files were found in the folder.'
                : 'Selected ${selected.length} source files from the folder.';
        _statusIsError = false;
        _isPickingSources = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Unable to pick folder: $error';
        _statusIsError = true;
        _isPickingSources = false;
      });
    }
  }

  void _clearSelection() {
    if (_isEncrypting) {
      return;
    }
    setState(() {
      _selectedSources.clear();
      _selectedSourceRoot = null;
      _statusMessage = 'Selected source files cleared.';
      _statusIsError = false;
    });
  }

  void _removeSelectedSource(_PendingSecureSource source) {
    if (_isEncrypting) {
      return;
    }

    setState(() {
      _selectedSources.remove(source);
      if (_selectedSources.isEmpty) {
        _selectedSourceRoot = null;
      }
      _statusMessage = 'Removed ${p.basename(source.sourcePath)} from the import list.';
      _statusIsError = false;
    });
  }

  Future<void> _removeSourcesByKind(SecureContentKind kind) async {
    if (_isEncrypting) {
      return;
    }

    final removedCount =
        _selectedSources.where((source) => source.kind == kind).length;
    if (removedCount == 0) {
      return;
    }

    if (removedCount >= _bulkRemoveConfirmationThreshold) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Remove all ${_kindLabel(kind)}?'),
            content: Text(
              'This will remove $removedCount ${_kindLabel(kind)} item${removedCount == 1 ? '' : 's'} from the pending import list.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _selectedSources.removeWhere((source) => source.kind == kind);
      if (_selectedSources.isEmpty) {
        _selectedSourceRoot = null;
      }
      _statusMessage = 'Removed $removedCount ${_kindLabel(kind)} item${removedCount == 1 ? '' : 's'} from the import list.';
      _statusIsError = false;
    });
  }

  Future<void> _encryptSelection() async {
    if (_isEncrypting || _selectedSources.isEmpty) {
      return;
    }

    final destinationByKind = _buildDestinationByKind();
    final missingDestinationKinds = _selectedSources
        .map((source) => source.kind)
        .where((kind) => (destinationByKind[kind] ?? '').isEmpty)
        .toSet()
        .toList(growable: false);
    if (missingDestinationKinds.isNotEmpty) {
      setState(() {
        _statusMessage =
            'Enter valid destination folders for ${missingDestinationKinds.map(_kindLabel).join(', ')}.';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _isEncrypting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final services = ref.read(appServicesProvider);
      final requests = _selectedSources
          .map(
            (source) => SecureContentEncryptionRequest(
              requestId: source.requestId,
              sourcePath: source.sourcePath,
              relativeOutputPath: p.join(
                destinationByKind[source.kind]!,
                source.relativeOutputPath,
              ),
            ),
          )
          .toList(growable: false);
      final result = await services.secureContentEncryptionJobManager.startBatch(
        requests: requests,
        overwrite: _overwriteExisting,
      );

      if (result.importedJson) {
        await ref.read(daylysportSyncControllerProvider.notifier).runManualSync();
      }
      await _refreshInventory();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = _buildEncryptionStatusMessage(result);
        _statusIsError = result.failedCount > 0;
        _isEncrypting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Secure import failed: $error';
        _statusIsError = true;
        _isEncrypting = false;
      });
    }
  }

  _PendingSecureSource? _buildPendingSource(
    String sourcePath,
    String relativeOutputPath,
  ) {
    final descriptor = const EncryptedFileResolver().describePath(sourcePath);
    if (descriptor.isEncrypted || descriptor.kind == SecureContentKind.other) {
      return null;
    }
    return _PendingSecureSource(
      requestId: 'selection-${_nextSelectionId++}',
      sourcePath: sourcePath,
      relativeOutputPath: relativeOutputPath.replaceAll('\\', '/'),
      kind: descriptor.kind,
    );
  }

  String _normalizeDestinationRoot(String raw) {
    final normalized = p.normalize(raw.trim().replaceAll('\\', '/'));
    final sanitized = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.' && segment != '..')
        .join('/');
    return sanitized;
  }

  Map<SecureContentKind, String> _buildDestinationByKind() {
    return <SecureContentKind, String>{
      SecureContentKind.json: _normalizeDestinationRoot(
        _jsonDestinationController.text,
      ),
      SecureContentKind.image: _normalizeDestinationRoot(
        _imageDestinationController.text,
      ),
      SecureContentKind.video: _normalizeDestinationRoot(
        _videoDestinationController.text,
      ),
    };
  }

  String _kindLabel(SecureContentKind kind) {
    switch (kind) {
      case SecureContentKind.json:
        return 'JSON';
      case SecureContentKind.image:
        return 'images';
      case SecureContentKind.video:
        return 'video';
      case SecureContentKind.other:
        return 'other';
    }
  }

  String _buildEncryptionStatusMessage(SecureContentEncryptionBatchResult result) {
    final parts = <String>[
      'Encrypted ${result.encryptedCount} of ${result.requestedCount} selected files.',
      if (result.skippedCount > 0) 'Skipped ${result.skippedCount}.',
      if (result.failedCount > 0) 'Failed ${result.failedCount}.',
      'JSON ${result.encryptedJsonCount}, images ${result.encryptedImageCount}, video ${result.encryptedVideoCount}.',
      if (result.importedJson) 'JSON sync was triggered after import.',
      if (result.manifestPath != null) 'Manifest: ${result.manifestPath}',
      if (result.failures.isNotEmpty)
        'First failure: ${p.basename(result.failures.first.sourcePath)} - ${result.failures.first.message}',
    ];
    return parts.join(' ');
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
                              _isPickingSources || _isEncrypting
                                  ? null
                                  : _pickFiles,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _isPickingSources ? 'Opening picker...' : 'Browse files',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _isPickingSources || _isEncrypting
                                  ? null
                                  : _pickFolder,
                          icon: const Icon(Icons.drive_folder_upload_rounded),
                          label: const Text('Browse folder'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _selectedSources.isEmpty || _isEncrypting
                                  ? null
                                  : _clearSelection,
                          icon: const Icon(Icons.clear_all_rounded),
                          label: const Text('Clear selection'),
                        ),
                        FilledButton.icon(
                          onPressed:
                              _isWarmingCaches || _isClearingCaches || _isEncrypting
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
                              _isWarmingCaches || _isClearingCaches || _isEncrypting
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
                    const SizedBox(height: 16),
                    _EncryptionImportPanel(
                      selectedSources: _selectedSources,
                      selectedSourceRoot: _selectedSourceRoot,
                      jobSnapshot: _jobSnapshot,
                      destinationByKind: _buildDestinationByKind(),
                      jsonDestinationController: _jsonDestinationController,
                      imageDestinationController: _imageDestinationController,
                      videoDestinationController: _videoDestinationController,
                      overwriteExisting: _overwriteExisting,
                      isEncrypting: _isEncrypting,
                      onApplyPreset: (kind, value) {
                        final controller = switch (kind) {
                          SecureContentKind.json => _jsonDestinationController,
                          SecureContentKind.image => _imageDestinationController,
                          SecureContentKind.video => _videoDestinationController,
                          SecureContentKind.other => _jsonDestinationController,
                        };
                        controller.text = value;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                        setState(() {});
                      },
                      onOverwriteChanged: (value) {
                        setState(() {
                          _overwriteExisting = value;
                        });
                      },
                      onRemoveAllByKind: _removeSourcesByKind,
                      onRemoveSource: _removeSelectedSource,
                      onImport: _encryptSelection,
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

class _PendingSecureSource {
  const _PendingSecureSource({
    required this.requestId,
    required this.sourcePath,
    required this.relativeOutputPath,
    required this.kind,
  });

  final String requestId;
  final String sourcePath;
  final String relativeOutputPath;
  final SecureContentKind kind;
}

class _EncryptionImportPanel extends StatelessWidget {
  const _EncryptionImportPanel({
    required this.selectedSources,
    required this.selectedSourceRoot,
    required this.jobSnapshot,
    required this.destinationByKind,
    required this.jsonDestinationController,
    required this.imageDestinationController,
    required this.videoDestinationController,
    required this.overwriteExisting,
    required this.isEncrypting,
    required this.onApplyPreset,
    required this.onOverwriteChanged,
    required this.onRemoveAllByKind,
    required this.onRemoveSource,
    required this.onImport,
  });

  final List<_PendingSecureSource> selectedSources;
  final String? selectedSourceRoot;
  final SecureContentEncryptionJobSnapshot jobSnapshot;
  final Map<SecureContentKind, String> destinationByKind;
  final TextEditingController jsonDestinationController;
  final TextEditingController imageDestinationController;
  final TextEditingController videoDestinationController;
  final bool overwriteExisting;
  final bool isEncrypting;
  final void Function(SecureContentKind kind, String value) onApplyPreset;
  final ValueChanged<bool> onOverwriteChanged;
  final Future<void> Function(SecureContentKind kind) onRemoveAllByKind;
  final ValueChanged<_PendingSecureSource> onRemoveSource;
  final VoidCallback onImport;

  static const Map<SecureContentKind, List<String>> _presetsByKind =
      <SecureContentKind, List<String>>{
        SecureContentKind.json: <String>['json', 'imports/json', 'catalog'],
        SecureContentKind.image: <String>['news', 'teams', 'players', 'images'],
        SecureContentKind.video: <String>[
          'reels',
          'highlights',
          'video-news',
          'updates',
          'video',
        ],
      };

  @override
  Widget build(BuildContext context) {
    final jsonCount = selectedSources
        .where((item) => item.kind == SecureContentKind.json)
        .length;
    final imageCount = selectedSources
        .where((item) => item.kind == SecureContentKind.image)
        .length;
    final videoCount = selectedSources
        .where((item) => item.kind == SecureContentKind.video)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Encrypt and import files',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Select plain JSON, image, or video files and encrypt them directly into the daylySport folder. Output files use .esj, .esi, and .esv, and each batch writes a manifest under manifest/secure_imports.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _DestinationPresetEditor(
            kind: SecureContentKind.json,
            label: 'JSON destination',
            hintText: 'json or imports/json',
            controller: jsonDestinationController,
            presets: _presetsByKind[SecureContentKind.json]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          _DestinationPresetEditor(
            kind: SecureContentKind.image,
            label: 'Image destination',
            hintText: 'news or teams',
            controller: imageDestinationController,
            presets: _presetsByKind[SecureContentKind.image]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          _DestinationPresetEditor(
            kind: SecureContentKind.video,
            label: 'Video destination',
            hintText: 'reels, highlights, or video-news',
            controller: videoDestinationController,
            presets: _presetsByKind[SecureContentKind.video]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Overwrite existing encrypted outputs'),
            subtitle: const Text(
              'When enabled, matching .esj, .esi, or .esv files are replaced.',
            ),
            value: overwriteExisting,
            onChanged: isEncrypting ? null : onOverwriteChanged,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(label: 'Selected', value: '${selectedSources.length}'),
              _StatChip(label: 'JSON', value: '$jsonCount'),
              _StatChip(label: 'Images', value: '$imageCount'),
              _StatChip(label: 'Video', value: '$videoCount'),
            ],
          ),
          if (jobSnapshot.totalFiles > 0) ...[
            const SizedBox(height: 12),
            _EncryptionProgressSection(snapshot: jobSnapshot),
          ],
          if (selectedSources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (jsonCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.data_object_rounded, size: 18),
                    label: Text('Remove all JSON ($jsonCount)'),
                    onPressed:
                        isEncrypting
                            ? null
                            : () {
                              onRemoveAllByKind(SecureContentKind.json);
                            },
                  ),
                if (imageCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text('Remove all images ($imageCount)'),
                    onPressed:
                        isEncrypting
                            ? null
                            : () {
                              onRemoveAllByKind(SecureContentKind.image);
                            },
                  ),
                if (videoCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.video_library_outlined, size: 18),
                    label: Text('Remove all videos ($videoCount)'),
                    onPressed:
                        isEncrypting
                            ? null
                            : () {
                              onRemoveAllByKind(SecureContentKind.video);
                            },
                  ),
              ],
            ),
          ],
          if (selectedSourceRoot != null) ...[
            const SizedBox(height: 10),
            Text(
              'Source folder: $selectedSourceRoot',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (selectedSources.isEmpty)
            Text(
              'No source files selected yet.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _SelectedSourcesReviewTable(
              selectedSources: selectedSources,
              jobSnapshot: jobSnapshot,
              destinationByKind: destinationByKind,
              onRemoveSource: onRemoveSource,
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: selectedSources.isEmpty || isEncrypting ? null : onImport,
            icon: const Icon(Icons.lock_rounded),
            label: Text(
              isEncrypting ? 'Encrypting and importing...' : 'Encrypt into daylySport',
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationPresetEditor extends StatelessWidget {
  const _DestinationPresetEditor({
    required this.kind,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.presets,
    required this.onApplyPreset,
  });

  final SecureContentKind kind;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final List<String> presets;
  final void Function(SecureContentKind kind, String value) onApplyPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              ActionChip(
                label: Text(preset),
                onPressed: () => onApplyPreset(kind, preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _SelectedSourcesReviewTable extends StatelessWidget {
  const _SelectedSourcesReviewTable({
    required this.selectedSources,
    required this.jobSnapshot,
    required this.destinationByKind,
    required this.onRemoveSource,
  });

  final List<_PendingSecureSource> selectedSources;
  final SecureContentEncryptionJobSnapshot jobSnapshot;
  final Map<SecureContentKind, String> destinationByKind;
  final ValueChanged<_PendingSecureSource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    final progressByRequestId = <String, SecureContentEncryptionJobItemState>{
      for (final item in jobSnapshot.items) item.requestId: item,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review before import',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Encrypted output')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Progress')),
              DataColumn(label: Text('Remove')),
            ],
            rows: selectedSources.map((source) {
              final itemState = progressByRequestId[source.requestId];
              final destinationRoot = destinationByKind[source.kind] ?? '';
              final outputPath = destinationRoot.isEmpty
                  ? source.relativeOutputPath
                  : p.join(destinationRoot, source.relativeOutputPath);
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          _iconForKind(source.kind),
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(_kindText(source.kind)),
                      ],
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        source.relativeOutputPath,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        itemState?.destinationPath ??
                            _encryptedPreviewPath(outputPath, source.kind),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(_statusLabel(itemState?.stage)),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LinearProgressIndicator(
                            value: itemState?.percentComplete,
                            minHeight: 8,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _progressLabel(itemState),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Remove file',
                      onPressed: () => onRemoveSource(source),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  static IconData _iconForKind(SecureContentKind kind) {
    switch (kind) {
      case SecureContentKind.json:
        return Icons.data_object_rounded;
      case SecureContentKind.image:
        return Icons.image_outlined;
      case SecureContentKind.video:
        return Icons.video_library_outlined;
      case SecureContentKind.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  static String _kindText(SecureContentKind kind) {
    switch (kind) {
      case SecureContentKind.json:
        return 'JSON';
      case SecureContentKind.image:
        return 'Image';
      case SecureContentKind.video:
        return 'Video';
      case SecureContentKind.other:
        return 'Other';
    }
  }

  static String _encryptedPreviewPath(String logicalPath, SecureContentKind kind) {
    switch (kind) {
      case SecureContentKind.json:
        return '$logicalPath$kEncryptedJsonExtension';
      case SecureContentKind.image:
        return '$logicalPath$kEncryptedImageExtension';
      case SecureContentKind.video:
        return '$logicalPath$kEncryptedMediaExtension';
      case SecureContentKind.other:
        return logicalPath;
    }
  }

  static String _statusLabel(SecureContentEncryptionItemStage? stage) {
    switch (stage) {
      case SecureContentEncryptionItemStage.preparing:
        return 'Preparing';
      case SecureContentEncryptionItemStage.queued:
        return 'Queued';
      case SecureContentEncryptionItemStage.encrypting:
        return 'Encrypting';
      case SecureContentEncryptionItemStage.writingOutput:
        return 'Writing output';
      case SecureContentEncryptionItemStage.completed:
        return 'Completed';
      case SecureContentEncryptionItemStage.skipped:
        return 'Skipped';
      case SecureContentEncryptionItemStage.failed:
        return 'Failed';
      case null:
        return 'Waiting';
    }
  }

  static String _progressLabel(SecureContentEncryptionJobItemState? itemState) {
    if (itemState == null) {
      return '0%';
    }
    final percent = (itemState.percentComplete * 100).round();
    final bytesLabel = itemState.totalBytes > 0
        ? ' • ${_humanizeBytes(itemState.processedBytes)} / ${_humanizeBytes(itemState.totalBytes)}'
        : '';
    return '$percent%$bytesLabel';
  }
}

class _EncryptionProgressSection extends StatelessWidget {
  const _EncryptionProgressSection({required this.snapshot});

  final SecureContentEncryptionJobSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final percent = (snapshot.percentComplete * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.isRunning ? 'Encryption in progress' : 'Last encryption batch',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: snapshot.isRunning ? snapshot.percentComplete : 1,
            minHeight: 10,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(label: 'Total', value: '${snapshot.totalFiles}'),
              _StatChip(label: 'Completed', value: '${snapshot.completedFiles}'),
              _StatChip(label: 'Queued', value: '${snapshot.queuedFiles}'),
              _StatChip(label: 'Failed', value: '${snapshot.failedFiles}'),
              _StatChip(label: 'Skipped', value: '${snapshot.skippedFiles}'),
              _StatChip(label: 'Progress', value: '$percent%'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            snapshot.currentFileName == null
                ? (snapshot.statusText ?? 'Waiting for work.')
                : 'Current file: ${snapshot.currentFileName} • ${snapshot.statusText ?? ''}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _humanizeBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  const units = <String>['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
}

Future<List<String>> collectEncryptableSourceFilesInIsolate(String rootPath) {
  return Isolate.run(() => collectEncryptableSourceFiles(rootPath));
}

List<String> collectEncryptableSourceFiles(String rootPath) {
  final resolver = const EncryptedFileResolver();
  final directory = Directory(rootPath);
  if (!directory.existsSync()) {
    return const <String>[];
  }

  final results = <String>[];
  for (final entity in directory.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final descriptor = resolver.describePath(entity.path);
    if (descriptor.isEncrypted || descriptor.kind == SecureContentKind.other) {
      continue;
    }
    results.add(entity.path);
  }

  results.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return results;
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
