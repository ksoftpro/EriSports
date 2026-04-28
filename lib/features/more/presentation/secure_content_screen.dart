import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:eri_sports/features/admin/data/admin_providers.dart';
import 'package:eri_sports/features/more/presentation/secure_content_import_routing.dart';
import 'package:eri_sports/features/verification/data/content_verification_service.dart';
import 'package:eri_sports/features/verification/presentation/admin_verification_qr_screen.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

const adminDashboardOverviewKey = Key('adminDashboardOverview');
const adminDashboardUserActivityKey = Key('adminDashboardUserActivity');
const adminDashboardRecentActivityKey = Key('adminDashboardRecentActivity');
const adminDashboardMenuButtonKey = Key('adminDashboardMenuButton');
const adminDashboardHomeTabKey = Key('adminDashboardHomeTab');
const adminDashboardImportTabKey = Key('adminDashboardImportTab');
const adminDashboardOperationsTabKey = Key('adminDashboardOperationsTab');
const adminDashboardProfileTabKey = Key('adminDashboardProfileTab');
const adminDashboardStatsTabKey = Key('adminDashboardStatsTab');

enum _SecureContentDashboardTab { home, import, operation, profile, stats }

extension _SecureContentDashboardTabX on _SecureContentDashboardTab {
  String get label {
    switch (this) {
      case _SecureContentDashboardTab.home:
        return 'Home';
      case _SecureContentDashboardTab.import:
        return 'Import';
      case _SecureContentDashboardTab.operation:
        return 'Operation';
      case _SecureContentDashboardTab.profile:
        return 'Profile';
      case _SecureContentDashboardTab.stats:
        return 'Stats';
    }
  }

  IconData get icon {
    switch (this) {
      case _SecureContentDashboardTab.home:
        return Icons.dashboard_outlined;
      case _SecureContentDashboardTab.import:
        return Icons.file_upload_outlined;
      case _SecureContentDashboardTab.operation:
        return Icons.settings_suggest_outlined;
      case _SecureContentDashboardTab.profile:
        return Icons.admin_panel_settings_outlined;
      case _SecureContentDashboardTab.stats:
        return Icons.query_stats_outlined;
    }
  }

  Key get key {
    switch (this) {
      case _SecureContentDashboardTab.home:
        return adminDashboardHomeTabKey;
      case _SecureContentDashboardTab.import:
        return adminDashboardImportTabKey;
      case _SecureContentDashboardTab.operation:
        return adminDashboardOperationsTabKey;
      case _SecureContentDashboardTab.profile:
        return adminDashboardProfileTabKey;
      case _SecureContentDashboardTab.stats:
        return adminDashboardStatsTabKey;
    }
  }
}

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
  static const List<String> _allowedVideoSourceExtensions = <String>[
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
      TextEditingController(text: 'highlights');
  final TextEditingController _reelsDestinationController =
      TextEditingController(text: 'reels');
  final TextEditingController _verificationRequestController =
      TextEditingController();
  final List<_PendingSecureSource> _selectedSources = <_PendingSecureSource>[];
  VerificationQrPayload? _generatedVerificationQr;
  String? _verificationMessage;
  bool _verificationMessageIsError = false;
  bool _isGeneratingVerificationCode = false;
  bool _isClearingVerificationRecords = false;

  @override
  void initState() {
    super.initState();
    _jobManager =
        ref.read(appServicesProvider).secureContentEncryptionJobManager;
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
    _reelsDestinationController.dispose();
    _verificationRequestController.dispose();
    super.dispose();
  }

  AdminSessionRecord? get _currentSession {
    return ref.read(adminAuthServiceProvider).currentSession;
  }

  Future<void> _recordDashboardActivity({
    required AdminActivityType type,
    required String summary,
    required String category,
    int? itemCount,
    int? totalBytes,
    Map<String, String>? metadata,
  }) {
    final session = _currentSession;
    if (session == null) {
      return Future<void>.value();
    }
    return ref
        .read(appServicesProvider)
        .adminActivityService
        .record(
          AdminActivityRecord(
            id: adminGenerateId(prefix: 'activity'),
            type: type,
            occurredAtUtc: DateTime.now().toUtc(),
            summary: summary,
            category: category,
            actorUserId: session.userId,
            actorUsername: session.username,
            itemCount: itemCount,
            totalBytes: totalBytes,
            metadata: metadata,
          ),
        );
  }

  Future<void> _refreshInventory({bool recordActivity = true}) async {
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
      if (recordActivity) {
        await _recordDashboardActivity(
          type: AdminActivityType.inventoryRefresh,
          summary: 'Refreshed secure content inventory from local storage.',
          category: 'operations',
          itemCount: inventory.supportedFiles,
          totalBytes: inventory.totalEncryptedBytes,
        );
      }
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
      await _recordDashboardActivity(
        type: AdminActivityType.warmCaches,
        summary: 'Prewarmed JSON, image, and video secure caches.',
        category: 'maintenance',
      );
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
      await _recordDashboardActivity(
        type: AdminActivityType.clearCaches,
        summary: 'Cleared all decrypted runtime caches.',
        category: 'maintenance',
      );
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

  Future<void> _pickFiles({
    SecureVideoImportCategory? defaultVideoCategory,
    bool videoOnly = false,
  }) async {
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
        allowedExtensions:
            videoOnly
                ? _allowedVideoSourceExtensions
                : _allowedSourceExtensions,
        dialogTitle: switch ((videoOnly, defaultVideoCategory)) {
          (true, SecureVideoImportCategory.reels) =>
            'Select video files for the reels destination',
          (true, _) => 'Select video files for the video destination',
          _ => 'Select JSON, image, or video files',
        },
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
        final source = _buildPendingSource(
          path,
          p.basename(path),
          defaultVideoCategory: defaultVideoCategory,
        );
        if (source != null) {
          selected.add(source);
        }
      }

      final categorySuffix =
          videoOnly
              ? ' routed to ${defaultVideoCategory?.label ?? 'Video'}.'
              : '';

      setState(() {
        _selectedSourceRoot = null;
        _selectedSources
          ..clear()
          ..addAll(selected);
        _statusMessage =
            selected.isEmpty
                ? 'No supported plain JSON, image, or video files were selected.'
                : 'Selected ${selected.length} source files for encryption.$categorySuffix';
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

      final filePaths = await collectEncryptableSourceFilesInIsolate(
        folderPath,
      );
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
      _statusMessage =
          'Removed ${p.basename(source.sourcePath)} from the import list.';
      _statusIsError = false;
    });
  }

  Future<void> _removeSourcesBySlot(
    SecureContentImportDestinationSlot slot,
  ) async {
    if (_isEncrypting) {
      return;
    }

    final removedCount =
        _selectedSources
            .where((source) => source.destinationSlot == slot)
            .length;
    if (removedCount == 0) {
      return;
    }

    if (removedCount >= _bulkRemoveConfirmationThreshold) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Remove all ${slot.label.toLowerCase()} items?'),
            content: Text(
              'This will remove $removedCount ${slot.label.toLowerCase()} item${removedCount == 1 ? '' : 's'} from the pending import list.',
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
      _selectedSources.removeWhere((source) => source.destinationSlot == slot);
      if (_selectedSources.isEmpty) {
        _selectedSourceRoot = null;
      }
      _statusMessage =
          'Removed $removedCount ${slot.label.toLowerCase()} item${removedCount == 1 ? '' : 's'} from the import list.';
      _statusIsError = false;
    });
  }

  Future<void> _encryptSelection() async {
    if (_isEncrypting || _selectedSources.isEmpty) {
      return;
    }

    final destinationRoots = _buildDestinationRoots();
    final missingDestinationSlots = destinationRoots.missingSlotsFor(
      _selectedSources.map((source) => source.routingEntry),
    );
    if (missingDestinationSlots.isNotEmpty) {
      setState(() {
        _statusMessage =
            'Enter valid destination folders for ${missingDestinationSlots.map((slot) => slot.label).join(', ')}.';
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
      final selectedBytes = _selectedSources.fold<int>(0, (total, source) {
        try {
          return total + File(source.sourcePath).lengthSync();
        } catch (_) {
          return total;
        }
      });
      final selectedKinds =
          _selectedSources.map((source) => source.kind).toSet();
      final category = _activityCategoryForSelection(selectedKinds);
      final requests = _selectedSources
          .map(
            (source) => SecureContentEncryptionRequest(
              requestId: source.requestId,
              sourcePath: source.sourcePath,
              relativeOutputPath: destinationRoots.buildOutputPath(
                kind: source.kind,
                relativeOutputPath: source.relativeOutputPath,
                videoCategory: source.effectiveVideoCategory,
              ),
            ),
          )
          .toList(growable: false);
      final result = await services.secureContentEncryptionJobManager
          .startBatch(requests: requests, overwrite: _overwriteExisting);

      if (result.importedJson) {
        await ref
            .read(daylysportSyncControllerProvider.notifier)
            .runManualSync();
      }
      await _refreshInventory(recordActivity: false);
      await _recordDashboardActivity(
        type: AdminActivityType.encryptionBatch,
        summary:
            'Processed ${result.requestedCount} secure content item${result.requestedCount == 1 ? '' : 's'} for encryption.',
        category: category,
        itemCount: result.encryptedCount,
        totalBytes: selectedBytes,
        metadata: <String, String>{
          'requestedCount': '${result.requestedCount}',
          'failedCount': '${result.failedCount}',
          'skippedCount': '${result.skippedCount}',
        },
      );

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

  Future<void> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final displayNameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    var obscurePassword = true;
    var obscureConfirm = true;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Create admin user'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setLocalState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setLocalState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final result = await ref
                        .read(adminAuthServiceProvider)
                        .createUser(
                          username: usernameController.text,
                          displayName: displayNameController.text,
                          password: passwordController.text,
                          confirmPassword: confirmController.text,
                        );
                    if (!context.mounted) {
                      return;
                    }
                    if (!result.success) {
                      setLocalState(() {
                        errorMessage = result.message;
                      });
                      return;
                    }
                    navigator.pop();
                    _showStatus(result.message ?? 'Admin user created.');
                  },
                  child: const Text('Create user'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();
    displayNameController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _showProfileDialog(AdminSessionRecord session) async {
    final authService = ref.read(adminAuthServiceProvider);
    final currentUser = authService.users.firstWhere(
      (user) => user.id == session.userId,
    );
    final usernameController = TextEditingController(
      text: currentUser.username,
    );
    final displayNameController = TextEditingController(
      text: currentUser.displayName,
    );
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Account settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final result = await authService.updateCurrentProfile(
                      username: usernameController.text,
                      displayName: displayNameController.text,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    if (!result.success) {
                      setLocalState(() {
                        errorMessage = result.message;
                      });
                      return;
                    }
                    navigator.pop();
                    _showStatus('Account settings updated.');
                  },
                  child: const Text('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    usernameController.dispose();
    displayNameController.dispose();
  }

  Future<void> _showPasswordDialog() async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    final confirmController = TextEditingController();
    var obscureCurrent = true;
    var obscureNext = true;
    var obscureConfirm = true;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Change password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setLocalState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nextController,
                      obscureText: obscureNext,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setLocalState(() {
                              obscureNext = !obscureNext;
                            });
                          },
                          icon: Icon(
                            obscureNext
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setLocalState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final result = await ref
                        .read(adminAuthServiceProvider)
                        .changeCurrentPassword(
                          currentPassword: currentController.text,
                          newPassword: nextController.text,
                          confirmPassword: confirmController.text,
                        );
                    if (!context.mounted) {
                      return;
                    }
                    if (!result.success) {
                      setLocalState(() {
                        errorMessage = result.message;
                      });
                      return;
                    }
                    navigator.pop();
                    _showStatus('Password updated successfully.');
                  },
                  child: const Text('Update password'),
                ),
              ],
            );
          },
        );
      },
    );

    currentController.dispose();
    nextController.dispose();
    confirmController.dispose();
  }

  Future<void> _clearLoginRecords() async {
    final session = _currentSession;
    if (session == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear login records?'),
          content: const Text(
            'This removes persisted login, logout, and failed-sign-in records from the local audit history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear records'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(appServicesProvider)
        .adminActivityService
        .clearLoginRecords(
          actorUserId: session.userId,
          actorUsername: session.username,
        );
    _showStatus('Login records cleared.');
  }

  Future<void> _generateVerificationQr() async {
    if (_isGeneratingVerificationCode) {
      return;
    }

    final requestCode = _verificationRequestController.text.trim();
    if (requestCode.isEmpty) {
      setState(() {
        _verificationMessage =
            'Paste the client request code before generating a verification code.';
        _verificationMessageIsError = true;
      });
      return;
    }

    setState(() {
      _isGeneratingVerificationCode = true;
      _verificationMessage = null;
      _verificationMessageIsError = false;
    });

    try {
      final service = ref.read(contentVerificationServiceProvider);
      final request = service.parseClientRequest(requestCode);
      final verificationQr = service.generateVerificationQrPayload(
        feature: request.feature,
      );
      await _recordDashboardActivity(
        type: AdminActivityType.verificationCodeGenerated,
        summary:
            'Generated ${ContentVerificationService.featureLabel(request.feature).toLowerCase()} verification QR for ${request.pendingCounts.totalPending} pending item${request.pendingCounts.totalPending == 1 ? '' : 's'}.',
        category: 'verification',
        itemCount: request.pendingCounts.totalPending,
        metadata: <String, String>{
          'feature': request.feature,
          'requestDayKey': request.requestDayKey,
          'contentCategory': _verificationContentCategory(
            request.pendingCounts,
          ),
          'pendingCategories': request.pendingCounts.activeCategoryKeys.join(
            ',',
          ),
          'seedSource': request.seedSource.name,
          'verificationCode': verificationQr.verificationCode,
          'verificationQrIssuedAtUtc':
              verificationQr.issuedAtUtc.toIso8601String(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedVerificationQr = verificationQr;
        _verificationMessage =
            'Verification QR generated for ${ContentVerificationService.featureLabel(request.feature)}.';
        _verificationMessageIsError = false;
      });
      await _openVerificationQrScreen(verificationQr);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedVerificationQr = null;
        _verificationMessage = 'Unable to generate verification QR: $error';
        _verificationMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingVerificationCode = false;
        });
      }
    }
  }

  Future<void> _openVerificationQrScreen(VerificationQrPayload payload) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminVerificationQrScreen(payload: payload),
      ),
    );
  }

  Future<void> _clearVerificationRecords() async {
    if (_isClearingVerificationRecords) {
      return;
    }

    final session = _currentSession;
    if (session == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear verification generation records?'),
          content: const Text(
            'This removes persisted verification-code generation records from the local audit history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear records'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _isClearingVerificationRecords = true;
      _verificationMessage = null;
      _verificationMessageIsError = false;
    });

    try {
      await ref
          .read(appServicesProvider)
          .adminActivityService
          .clearVerificationCodeRecords(
            actorUserId: session.userId,
            actorUsername: session.username,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedVerificationQr = null;
        _verificationMessage = 'Verification generation records cleared.';
        _verificationMessageIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _verificationMessage = 'Unable to clear verification records: $error';
        _verificationMessageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isClearingVerificationRecords = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(adminAuthServiceProvider).logout();
    if (!mounted) {
      return;
    }
    context.go('/admin-login');
  }

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  _PendingSecureSource? _buildPendingSource(
    String sourcePath,
    String relativeOutputPath, {
    SecureVideoImportCategory? defaultVideoCategory,
  }) {
    final descriptor = const EncryptedFileResolver().describePath(sourcePath);
    if (descriptor.isEncrypted || descriptor.kind == SecureContentKind.other) {
      return null;
    }
    return _PendingSecureSource(
      requestId: 'selection-${_nextSelectionId++}',
      sourcePath: sourcePath,
      relativeOutputPath: relativeOutputPath.replaceAll('\\', '/'),
      kind: descriptor.kind,
      videoCategory:
          descriptor.kind == SecureContentKind.video
              ? (defaultVideoCategory ??
                  _suggestVideoImportCategory(relativeOutputPath))
              : null,
    );
  }

  SecureVideoImportCategory _suggestVideoImportCategory(
    String relativeOutputPath,
  ) {
    final normalized = relativeOutputPath.replaceAll('\\', '/').toLowerCase();
    if (normalized.startsWith('reels/') ||
        normalized.startsWith('shorts/') ||
        normalized.startsWith('short-videos/') ||
        normalized.startsWith('short_videos/') ||
        normalized.contains('/reels/') ||
        normalized.contains('/shorts/') ||
        normalized.contains('/short-videos/') ||
        normalized.contains('/short_videos/') ||
        normalized.contains('reel') ||
        normalized.contains('short')) {
      return SecureVideoImportCategory.reels;
    }
    return SecureVideoImportCategory.video;
  }

  String _normalizeDestinationRoot(String raw) {
    final normalized = p.normalize(raw.trim().replaceAll('\\', '/'));
    final sanitized = normalized
        .split('/')
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .join('/');
    return sanitized;
  }

  SecureContentDestinationRoots _buildDestinationRoots() {
    return SecureContentDestinationRoots(
      json: _normalizeDestinationRoot(_jsonDestinationController.text),
      image: _normalizeDestinationRoot(_imageDestinationController.text),
      video: _normalizeDestinationRoot(_videoDestinationController.text),
      reels: _normalizeDestinationRoot(_reelsDestinationController.text),
    );
  }

  String _activityCategoryForSelection(Set<SecureContentKind> selectedKinds) {
    if (selectedKinds.length == 1 &&
        selectedKinds.first == SecureContentKind.video) {
      final videoCategories =
          _selectedSources
              .where((source) => source.kind == SecureContentKind.video)
              .map((source) => source.effectiveVideoCategory)
              .toSet();
      if (videoCategories.length == 1) {
        return videoCategories.first.label.toLowerCase();
      }
      return 'mixed-video';
    }
    return selectedKinds.length == 1
        ? _kindLabel(selectedKinds.first).toLowerCase()
        : 'mixed';
  }

  void _assignVideoCategory(
    _PendingSecureSource source,
    SecureVideoImportCategory category,
  ) {
    if (_isEncrypting || source.kind != SecureContentKind.video) {
      return;
    }

    final index = _selectedSources.indexOf(source);
    if (index < 0) {
      return;
    }

    setState(() {
      _selectedSources[index] = source.copyWith(videoCategory: category);
      _statusMessage =
          'Routed ${p.basename(source.sourcePath)} to the ${category.label} destination.';
      _statusIsError = false;
    });
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

  String _buildEncryptionStatusMessage(
    SecureContentEncryptionBatchResult result,
  ) {
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

  String _verificationContentCategory(ContentVerificationPendingCounts counts) {
    final activeKeys = counts.activeCategoryKeys;
    if (activeKeys.isEmpty) {
      return 'none';
    }
    if (activeKeys.length == 1) {
      return activeKeys.first;
    }
    return 'mixed';
  }

  Widget _buildInventoryAsyncPanel() {
    if (_isRefreshing && _inventory == null) {
      return const _DashboardLoadingPanel();
    }
    if (_errorMessage != null) {
      return _DashboardErrorPanel(message: _errorMessage!);
    }
    return const _DashboardLoadingPanel();
  }

  Widget _buildTabPage({
    required List<Widget> Function(double maxWidth) childrenBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth =
            constraints.maxWidth > 1480 ? 1480.0 : constraints.maxWidth;
        return RefreshIndicator(
          onRefresh: _refreshInventory,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: childrenBuilder(pageWidth),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHomeTab({
    required double maxWidth,
    required AdminSessionRecord session,
    required SecureContentInventory? inventory,
    required _SecureContentDashboardSnapshot? snapshot,
  }) {
    return [
      _DashboardHeroCard(
        session: session,
        inventory: inventory,
        isRefreshing: _isRefreshing,
        onRefresh: _refreshInventory,
        onOpenSync: () => context.push('/sync'),
        onLogout: _logout,
      ),
      const SizedBox(height: 18),
      if (snapshot != null)
        _OverviewMetricsGrid(key: adminDashboardOverviewKey, snapshot: snapshot)
      else
        _buildInventoryAsyncPanel(),
      if (snapshot != null) ...[
        const SizedBox(height: 18),
        _DashboardPanelGrid(
          maxWidth: maxWidth,
          children: [
            _SectionCard(
              title: 'Category coverage',
              subtitle:
                  'Encrypted counts and storage footprint grouped by secure content type.',
              child: _CategoryStatisticsPanel(snapshot: snapshot),
            ),
            _SectionCard(
              title: 'Date and size trends',
              subtitle:
                  'Recent encrypted file volume grouped by file activity date and payload size.',
              child: _DateAndSizePanel(snapshot: snapshot),
            ),
            _SectionCard(
              key: adminDashboardUserActivityKey,
              title: 'User activity',
              subtitle:
                  'Local admin activity, import volume, and recent sign-in behavior.',
              child: _UserActivityPanel(snapshot: snapshot),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildImportTab({required double maxWidth}) {
    return [
      _DashboardTabIntroCard(
        icon: _SecureContentDashboardTab.import.icon,
        title: 'Import workspace',
        subtitle:
            'Keep source selection, destination routing, and encryption review in one focused workspace without crowding the rest of the admin dashboard.',
        badges: [
          _StatChip(label: 'Queued files', value: '${_selectedSources.length}'),
          _StatChip(
            label: 'Batch status',
            value:
                _jobSnapshot.isRunning
                    ? '${_jobSnapshot.settledFiles}/${_jobSnapshot.totalFiles}'
                    : 'Idle',
          ),
          _StatChip(
            label: 'Overwrite',
            value: _overwriteExisting ? 'Enabled' : 'Disabled',
          ),
        ],
      ),
      const SizedBox(height: 18),
      _SectionCard(
        title: 'Import and encrypt',
        subtitle:
            'All import and encryption operations remain unchanged; only the GUI layout has been reorganized for clarity.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isPickingSources || _isEncrypting
                          ? null
                          : () => _pickFiles(),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    _isPickingSources ? 'Opening picker...' : 'Browse files',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isPickingSources || _isEncrypting
                          ? null
                          : () => _pickFiles(
                            defaultVideoCategory:
                                SecureVideoImportCategory.video,
                            videoOnly: true,
                          ),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Browse videos'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isPickingSources || _isEncrypting
                          ? null
                          : () => _pickFiles(
                            defaultVideoCategory:
                                SecureVideoImportCategory.reels,
                            videoOnly: true,
                          ),
                  icon: const Icon(Icons.movie_filter_outlined),
                  label: const Text('Browse reels'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _isPickingSources || _isEncrypting ? null : _pickFolder,
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
              ],
            ),
            const SizedBox(height: 16),
            _EncryptionImportPanel(
              selectedSources: _selectedSources,
              selectedSourceRoot: _selectedSourceRoot,
              jobSnapshot: _jobSnapshot,
              destinationRoots: _buildDestinationRoots(),
              jsonDestinationController: _jsonDestinationController,
              imageDestinationController: _imageDestinationController,
              videoDestinationController: _videoDestinationController,
              reelsDestinationController: _reelsDestinationController,
              overwriteExisting: _overwriteExisting,
              isEncrypting: _isEncrypting,
              onApplyPreset: (kind, value) {
                final controller = switch (kind) {
                  SecureContentImportDestinationSlot.json =>
                    _jsonDestinationController,
                  SecureContentImportDestinationSlot.image =>
                    _imageDestinationController,
                  SecureContentImportDestinationSlot.video =>
                    _videoDestinationController,
                  SecureContentImportDestinationSlot.reels =>
                    _reelsDestinationController,
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
              onRemoveAllByKind: _removeSourcesBySlot,
              onAssignVideoCategory: _assignVideoCategory,
              onRemoveSource: _removeSelectedSource,
              onImport: _encryptSelection,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      _statusIsError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildOperationTab({
    required double maxWidth,
    required List<AdminActivityRecord> activities,
    required SecureContentInventory? inventory,
  }) {
    return [
      _DashboardTabIntroCard(
        icon: _SecureContentDashboardTab.operation.icon,
        title: 'Operations',
        subtitle:
            'Keep approval workflows and maintenance actions in a dedicated operational view so routine admin tasks are easier to scan and execute.',
        badges: [
          _StatChip(
            label: 'QR state',
            value: _generatedVerificationQr == null ? 'Idle' : 'Ready',
          ),
          _StatChip(
            label: 'Maintenance',
            value: _isWarmingCaches || _isClearingCaches ? 'Busy' : 'Available',
          ),
        ],
      ),
      const SizedBox(height: 18),
      _DashboardPanelGrid(
        maxWidth: maxWidth,
        children: [
          _SectionCard(
            title: 'Verification QR operations',
            subtitle:
                'Convert client request codes into scannable admin QR approvals, while preserving a manual verification-code fallback and the local audit trail.',
            child: _VerificationOperationsPanel(
              requestController: _verificationRequestController,
              generatedVerificationQr: _generatedVerificationQr,
              statusMessage: _verificationMessage,
              statusIsError: _verificationMessageIsError,
              isGenerating: _isGeneratingVerificationCode,
              isClearing: _isClearingVerificationRecords,
              activities: activities,
              onGenerate: _generateVerificationQr,
              onClearRecords: _clearVerificationRecords,
            ),
          ),
          _SectionCard(
            title: 'Maintenance controls',
            subtitle:
                'Prewarm secure caches, clear decrypted outputs, and verify scanner health.',
            child: _MaintenancePanel(
              inventory: inventory,
              isWarmingCaches: _isWarmingCaches,
              isClearingCaches: _isClearingCaches,
              isEncrypting: _isEncrypting,
              onWarmCaches: _warmCaches,
              onClearCaches: _clearCaches,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildProfileTab({
    required double maxWidth,
    required AdminSessionRecord session,
    required List<AdminUserRecord> users,
    required List<AdminActivityRecord> activities,
  }) {
    return [
      _DashboardTabIntroCard(
        icon: _SecureContentDashboardTab.profile.icon,
        title: 'Profile and security',
        subtitle:
            'Separate identity, account management, and audit visibility from operational tooling to keep administrative access workflows focused.',
        badges: [
          _StatChip(label: 'Admins', value: '${users.length}'),
          _StatChip(label: 'Audit rows', value: '${activities.length}'),
        ],
      ),
      const SizedBox(height: 18),
      _DashboardPanelGrid(
        maxWidth: maxWidth,
        children: [
          _SectionCard(
            title: 'User and security management',
            subtitle:
                'Manage the signed-in admin account, create additional admins, and review local access state.',
            child: _SecurityManagementPanel(
              session: session,
              users: users,
              onEditAccount: () => _showProfileDialog(session),
              onChangePassword: _showPasswordDialog,
              onCreateAdmin: _showCreateUserDialog,
              onClearLoginRecords: _clearLoginRecords,
            ),
          ),
          _SectionCard(
            key: adminDashboardRecentActivityKey,
            title: 'Recent activity and login records',
            subtitle:
                'Audit history for authentication, inventory, maintenance, and encryption jobs.',
            child: _RecentActivityPanel(activities: activities),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildStatsTab({
    required double maxWidth,
    required SecureContentInventory? inventory,
  }) {
    return [
      _DashboardTabIntroCard(
        icon: _SecureContentDashboardTab.stats.icon,
        title: 'Inventory and statistics',
        subtitle:
            'Review storage coverage, encrypted breakdowns, and detected inventory samples in a dedicated stats workspace designed for scanning large data surfaces.',
        badges: [
          _StatChip(
            label: 'Coverage',
            value:
                inventory == null
                    ? 'Pending'
                    : '${inventory.encryptedCoveragePercent}%',
          ),
          _StatChip(
            label: 'Encrypted files',
            value:
                inventory == null ? 'Pending' : '${inventory.encryptedFiles}',
          ),
          _StatChip(
            label: 'Plain files',
            value: inventory == null ? 'Pending' : '${inventory.plainFiles}',
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (inventory == null)
        _buildInventoryAsyncPanel()
      else ...[
        _DashboardPanelGrid(
          maxWidth: maxWidth,
          children: [
            _InventoryOverviewCard(inventory: inventory),
            _InventoryBreakdownCard(inventory: inventory),
          ],
        ),
        const SizedBox(height: 16),
        _InventorySamplesCard(inventory: inventory),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authService = ref.watch(adminAuthServiceProvider);
    final activityService = ref.watch(adminActivityServiceProvider);
    final session = authService.currentSession;
    final inventory = _inventory;
    final snapshot =
        session != null && inventory != null
            ? _SecureContentDashboardSnapshot(
              inventory: inventory,
              users: authService.users.toList(growable: false),
              activities: activityService.records.toList(growable: false),
              currentSession: session,
            )
            : null;

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return DefaultTabController(
      length: _SecureContentDashboardTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Content Operations'),
          actions: [
            IconButton(
              onPressed: _isRefreshing ? null : _refreshInventory,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Rescan offline content',
            ),
            PopupMenuButton<String>(
              key: adminDashboardMenuButtonKey,
              onSelected: (value) {
                switch (value) {
                  case 'profile':
                    _showProfileDialog(session);
                    break;
                  case 'password':
                    _showPasswordDialog();
                    break;
                  case 'user':
                    _showCreateUserDialog();
                    break;
                  case 'logins':
                    _clearLoginRecords();
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('Account settings'),
                  ),
                  PopupMenuItem<String>(
                    value: 'password',
                    child: Text('Change password'),
                  ),
                  PopupMenuItem<String>(
                    value: 'user',
                    child: Text('Create admin user'),
                  ),
                  PopupMenuItem<String>(
                    value: 'logins',
                    child: Text('Clear login records'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
                ];
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TabBar(
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                indicator: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                tabs: [
                  for (final tab in _SecureContentDashboardTab.values)
                    Tab(key: tab.key, icon: Icon(tab.icon), text: tab.label),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildTabPage(
              childrenBuilder:
                  (maxWidth) => _buildHomeTab(
                    maxWidth: maxWidth,
                    session: session,
                    inventory: inventory,
                    snapshot: snapshot,
                  ),
            ),
            _buildTabPage(
              childrenBuilder:
                  (maxWidth) => _buildImportTab(maxWidth: maxWidth),
            ),
            _buildTabPage(
              childrenBuilder:
                  (maxWidth) => _buildOperationTab(
                    maxWidth: maxWidth,
                    activities: activityService.records.toList(growable: false),
                    inventory: inventory,
                  ),
            ),
            _buildTabPage(
              childrenBuilder:
                  (maxWidth) => _buildProfileTab(
                    maxWidth: maxWidth,
                    session: session,
                    users: authService.users.toList(growable: false),
                    activities: activityService.records.toList(growable: false),
                  ),
            ),
            _buildTabPage(
              childrenBuilder:
                  (maxWidth) =>
                      _buildStatsTab(maxWidth: maxWidth, inventory: inventory),
            ),
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
    this.videoCategory,
  });

  final String requestId;
  final String sourcePath;
  final String relativeOutputPath;
  final SecureContentKind kind;
  final SecureVideoImportCategory? videoCategory;

  SecureVideoImportCategory get effectiveVideoCategory {
    return videoCategory ?? SecureVideoImportCategory.video;
  }

  SecureContentImportDestinationSlot get destinationSlot {
    switch (kind) {
      case SecureContentKind.json:
        return SecureContentImportDestinationSlot.json;
      case SecureContentKind.image:
        return SecureContentImportDestinationSlot.image;
      case SecureContentKind.video:
        return effectiveVideoCategory.slot;
      case SecureContentKind.other:
        return SecureContentImportDestinationSlot.video;
    }
  }

  SecureContentImportRoutingEntry get routingEntry {
    return SecureContentImportRoutingEntry(
      kind: kind,
      videoCategory: effectiveVideoCategory,
    );
  }

  _PendingSecureSource copyWith({SecureVideoImportCategory? videoCategory}) {
    return _PendingSecureSource(
      requestId: requestId,
      sourcePath: sourcePath,
      relativeOutputPath: relativeOutputPath,
      kind: kind,
      videoCategory: videoCategory ?? this.videoCategory,
    );
  }
}

class _SecureContentDashboardSnapshot {
  _SecureContentDashboardSnapshot({
    required this.inventory,
    required this.users,
    required this.activities,
    required this.currentSession,
  });

  final SecureContentInventory inventory;
  final List<AdminUserRecord> users;
  final List<AdminActivityRecord> activities;
  final AdminSessionRecord currentSession;

  int get todayActivityCount {
    final today = DateTime.now().toUtc();
    return activities
        .where((record) => _isSameUtcDay(record.occurredAtUtc, today))
        .length;
  }

  int get totalImportedItems {
    return activities
        .where((record) => record.type == AdminActivityType.encryptionBatch)
        .fold<int>(0, (sum, record) => sum + (record.itemCount ?? 0));
  }

  int get totalImportedBytes {
    return activities
        .where((record) => record.type == AdminActivityType.encryptionBatch)
        .fold<int>(0, (sum, record) => sum + (record.totalBytes ?? 0));
  }

  int get totalEncryptedFiles => inventory.encryptedFiles;

  int get totalEncryptedBytes => inventory.totalEncryptedBytes;

  List<_CategoryDashboardMetric> get categoryMetrics {
    final metrics = <_CategoryDashboardMetric>[
      _CategoryDashboardMetric(
        kind: SecureContentKind.json,
        label: 'JSON',
        count: inventory.encryptedJsonFiles,
        bytes: inventory.encryptedJsonBytes,
        icon: Icons.data_object_rounded,
      ),
      _CategoryDashboardMetric(
        kind: SecureContentKind.image,
        label: 'Images',
        count: inventory.encryptedImageFiles,
        bytes: inventory.encryptedImageBytes,
        icon: Icons.image_outlined,
      ),
      _CategoryDashboardMetric(
        kind: SecureContentKind.video,
        label: 'Video',
        count: inventory.encryptedVideoFiles,
        bytes: inventory.encryptedVideoBytes,
        icon: Icons.video_library_outlined,
      ),
    ];
    metrics.sort((left, right) => right.bytes.compareTo(left.bytes));
    return metrics;
  }

  List<_DateDashboardMetric> get dateMetrics {
    return inventory.encryptedDateBuckets
        .map((bucket) {
          final actionCount =
              activities
                  .where(
                    (record) =>
                        _isSameUtcDay(record.occurredAtUtc, bucket.dayUtc),
                  )
                  .length;
          return _DateDashboardMetric(
            dayUtc: bucket.dayUtc,
            encryptedCount: bucket.encryptedFiles,
            encryptedBytes: bucket.encryptedBytes,
            actionCount: actionCount,
          );
        })
        .toList(growable: false);
  }

  List<_UserActivityMetric> get userMetrics {
    final entries = <_UserActivityMetric>[];
    for (final user in users) {
      final userRecords = activities
          .where((record) => record.actorUserId == user.id)
          .toList(growable: false);
      final imports = userRecords
          .where((record) => record.type == AdminActivityType.encryptionBatch)
          .toList(growable: false);
      entries.add(
        _UserActivityMetric(
          user: user,
          actionCount: userRecords.length,
          importCount: imports.fold<int>(
            0,
            (sum, record) => sum + (record.itemCount ?? 0),
          ),
          importedBytes: imports.fold<int>(
            0,
            (sum, record) => sum + (record.totalBytes ?? 0),
          ),
          loginCount:
              userRecords
                  .where(
                    (record) => record.type == AdminActivityType.loginSuccess,
                  )
                  .length,
          lastActiveAtUtc:
              userRecords.isEmpty
                  ? user.lastLoginAtUtc
                  : userRecords.first.occurredAtUtc,
          isCurrentUser: user.id == currentSession.userId,
        ),
      );
    }
    entries.sort((left, right) {
      final actionCompare = right.actionCount.compareTo(left.actionCount);
      if (actionCompare != 0) {
        return actionCompare;
      }
      final leftLast = left.lastActiveAtUtc;
      final rightLast = right.lastActiveAtUtc;
      if (leftLast == null && rightLast == null) {
        return 0;
      }
      if (leftLast == null) {
        return 1;
      }
      if (rightLast == null) {
        return -1;
      }
      return rightLast.compareTo(leftLast);
    });
    return entries;
  }

  String get dominantCategoryLabel {
    final topCategory = categoryMetrics.firstWhere(
      (metric) => metric.count > 0 || metric.bytes > 0,
      orElse:
          () => _CategoryDashboardMetric(
            kind: SecureContentKind.json,
            label: 'JSON',
            count: 0,
            bytes: 0,
            icon: Icons.data_object_rounded,
          ),
    );
    return topCategory.label;
  }

  static bool _isSameUtcDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _CategoryDashboardMetric {
  const _CategoryDashboardMetric({
    required this.kind,
    required this.label,
    required this.count,
    required this.bytes,
    required this.icon,
  });

  final SecureContentKind kind;
  final String label;
  final int count;
  final int bytes;
  final IconData icon;
}

class _DateDashboardMetric {
  const _DateDashboardMetric({
    required this.dayUtc,
    required this.encryptedCount,
    required this.encryptedBytes,
    required this.actionCount,
  });

  final DateTime dayUtc;
  final int encryptedCount;
  final int encryptedBytes;
  final int actionCount;
}

class _UserActivityMetric {
  const _UserActivityMetric({
    required this.user,
    required this.actionCount,
    required this.importCount,
    required this.importedBytes,
    required this.loginCount,
    required this.lastActiveAtUtc,
    required this.isCurrentUser,
  });

  final AdminUserRecord user;
  final int actionCount;
  final int importCount;
  final int importedBytes;
  final int loginCount;
  final DateTime? lastActiveAtUtc;
  final bool isCurrentUser;
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.session,
    required this.inventory,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onOpenSync,
    required this.onLogout,
  });

  final AdminSessionRecord session;
  final SecureContentInventory? inventory;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSync;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('MMM d, HH:mm');
    final inventoryData = inventory;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.primary.withValues(alpha: 0.12),
            scheme.surfaceContainerHighest,
            scheme.tertiary.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 12,
              spacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional control surface for encrypted daylySport operations',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Signed in as ${session.displayName} (${session.username}). Use this dashboard to manage encrypted imports, runtime caches, local admin access, and the audit trail behind every secure content action.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: isRefreshing ? null : onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        isRefreshing ? 'Refreshing...' : 'Refresh inventory',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSync,
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Open sync tools'),
                    ),
                    TextButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HeroChip(
                  label: 'Session started',
                  value: formatter.format(session.authenticatedAtUtc.toLocal()),
                ),
                _HeroChip(label: 'Formats', value: '.esj  .esi  .esv'),
                _HeroChip(
                  label: 'Last scan',
                  value:
                      inventoryData == null
                          ? 'Pending'
                          : formatter.format(
                            inventoryData.scannedAtUtc.toLocal(),
                          ),
                ),
                _HeroChip(
                  label: 'Encrypted coverage',
                  value:
                      inventoryData == null
                          ? 'Pending'
                          : '${inventoryData.encryptedCoveragePercent}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _OverviewMetricsGrid extends StatelessWidget {
  const _OverviewMetricsGrid({super.key, required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = <_OverviewMetricData>[
      _OverviewMetricData(
        label: 'Encrypted files',
        value: '${snapshot.totalEncryptedFiles}',
        supportingText: 'Current encrypted runtime footprint',
        icon: Icons.lock_outline_rounded,
      ),
      _OverviewMetricData(
        label: 'Encrypted size',
        value: _humanizeBytes(snapshot.totalEncryptedBytes),
        supportingText: 'Storage currently protected at rest',
        icon: Icons.storage_rounded,
      ),
      _OverviewMetricData(
        label: 'Today activity',
        value: '${snapshot.todayActivityCount}',
        supportingText: 'Local admin actions recorded today',
        icon: Icons.timeline_rounded,
      ),
      _OverviewMetricData(
        label: 'Admins',
        value: '${snapshot.users.length}',
        supportingText: 'Configured local admin accounts',
        icon: Icons.groups_rounded,
      ),
      _OverviewMetricData(
        label: 'Imported items',
        value: '${snapshot.totalImportedItems}',
        supportingText: 'Encrypted through tracked dashboard batches',
        icon: Icons.file_upload_outlined,
      ),
      _OverviewMetricData(
        label: 'Imported bytes',
        value: _humanizeBytes(snapshot.totalImportedBytes),
        supportingText: 'Total source payload processed locally',
        icon: Icons.compress_rounded,
      ),
      _OverviewMetricData(
        label: 'Coverage',
        value: '${snapshot.inventory.encryptedCoveragePercent}%',
        supportingText: 'Supported files already encrypted',
        icon: Icons.verified_user_outlined,
      ),
      _OverviewMetricData(
        label: 'Dominant category',
        value: snapshot.dominantCategoryLabel,
        supportingText: 'Largest encrypted category by stored bytes',
        icon: Icons.insights_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns =
            width >= 1200
                ? 4
                : width >= 820
                ? 2
                : 1;
        const spacing = 14.0;
        final tileWidth =
            columns == 1
                ? width
                : (width - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: tileWidth,
                child: _OverviewMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _OverviewMetricData {
  const _OverviewMetricData({
    required this.label,
    required this.value,
    required this.supportingText,
    required this.icon,
  });

  final String label;
  final String value;
  final String supportingText;
  final IconData icon;
}

class _OverviewMetricCard extends StatelessWidget {
  const _OverviewMetricCard({required this.metric});

  final _OverviewMetricData metric;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: scheme.primary),
          const SizedBox(height: 16),
          Text(metric.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(metric.value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            metric.supportingText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DashboardPanelGrid extends StatelessWidget {
  const _DashboardPanelGrid({required this.maxWidth, required this.children});

  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final columns =
        maxWidth >= 1360
            ? 3
            : maxWidth >= 900
            ? 2
            : 1;
    const spacing = 16.0;
    final itemWidth =
        columns == 1
            ? maxWidth
            : (maxWidth - ((columns - 1) * spacing)) / columns;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final child in children) SizedBox(width: itemWidth, child: child),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DashboardTabIntroCard extends StatelessWidget {
  const _DashboardTabIntroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badges = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.primary.withValues(alpha: 0.1),
            scheme.surfaceContainerLow,
            scheme.secondary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: badges),
          ],
        ],
      ),
    );
  }
}

class _CategoryStatisticsPanel extends StatelessWidget {
  const _CategoryStatisticsPanel({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final totalFiles = math.max(1, snapshot.totalEncryptedFiles);
    return Column(
      children: [
        for (final metric in snapshot.categoryMetrics) ...[
          Row(
            children: [
              Icon(
                metric.icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${metric.count} encrypted items • ${_humanizeBytes(metric.bytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${((metric.count / totalFiles) * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: metric.count / totalFiles,
            minHeight: 8,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DateAndSizePanel extends StatelessWidget {
  const _DateAndSizePanel({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = snapshot.dateMetrics.take(6).toList(growable: false);
    final maxCount = metrics.fold<int>(
      1,
      (maxValue, item) => math.max(maxValue, item.encryptedCount),
    );
    final formatter = DateFormat('MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              label: 'Largest day',
              value:
                  metrics.isEmpty
                      ? 'No data'
                      : '${metrics.first.encryptedCount} items',
            ),
            _StatChip(
              label: 'Encrypted size',
              value: _humanizeBytes(snapshot.totalEncryptedBytes),
            ),
            _StatChip(
              label: 'Avg item size',
              value:
                  snapshot.totalEncryptedFiles == 0
                      ? '0 B'
                      : _humanizeBytes(
                        (snapshot.totalEncryptedBytes /
                                snapshot.totalEncryptedFiles)
                            .round(),
                      ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (metrics.isEmpty)
          Text(
            'No encrypted files have been detected yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (final metric in metrics) ...[
            Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Text(formatter.format(metric.dayUtc.toLocal())),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: metric.encryptedCount / maxCount,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: Text(
                    '${metric.encryptedCount} files',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_humanizeBytes(metric.encryptedBytes)} • ${metric.actionCount} admin action${metric.actionCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _UserActivityPanel extends StatelessWidget {
  const _UserActivityPanel({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    return Column(
      children: [
        for (final entry in snapshot.userMetrics) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.user.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (entry.isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Current session',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('@${entry.user.username}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(label: 'Actions', value: '${entry.actionCount}'),
                    _StatChip(label: 'Imports', value: '${entry.importCount}'),
                    _StatChip(
                      label: 'Imported size',
                      value: _humanizeBytes(entry.importedBytes),
                    ),
                    _StatChip(label: 'Logins', value: '${entry.loginCount}'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  entry.lastActiveAtUtc == null
                      ? 'No recorded activity yet.'
                      : 'Last active ${formatter.format(entry.lastActiveAtUtc!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MaintenancePanel extends StatelessWidget {
  const _MaintenancePanel({
    required this.inventory,
    required this.isWarmingCaches,
    required this.isClearingCaches,
    required this.isEncrypting,
    required this.onWarmCaches,
    required this.onClearCaches,
  });

  final SecureContentInventory? inventory;
  final bool isWarmingCaches;
  final bool isClearingCaches;
  final bool isEncrypting;
  final Future<void> Function() onWarmCaches;
  final Future<void> Function() onClearCaches;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    final inventoryData = inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed:
                  isWarmingCaches || isClearingCaches || isEncrypting
                      ? null
                      : onWarmCaches,
              icon: const Icon(Icons.bolt_rounded),
              label: Text(
                isWarmingCaches ? 'Warming caches...' : 'Warm secure caches',
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  isWarmingCaches || isClearingCaches || isEncrypting
                      ? null
                      : onClearCaches,
              icon: const Icon(Icons.cleaning_services_rounded),
              label: Text(
                isClearingCaches
                    ? 'Clearing caches...'
                    : 'Clear decrypted caches',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (inventoryData != null)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                label: 'Supported files',
                value: '${inventoryData.supportedFiles}',
              ),
              _StatChip(
                label: 'Plain files',
                value: '${inventoryData.plainFiles}',
              ),
              _StatChip(
                label: 'Encrypted files',
                value: '${inventoryData.encryptedFiles}',
              ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          inventoryData == null
              ? 'Inventory data is still loading.'
              : 'Last inventory scan completed ${formatter.format(inventoryData.scannedAtUtc.toLocal())}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _SecurityManagementPanel extends StatelessWidget {
  const _SecurityManagementPanel({
    required this.session,
    required this.users,
    required this.onEditAccount,
    required this.onChangePassword,
    required this.onCreateAdmin,
    required this.onClearLoginRecords,
  });

  final AdminSessionRecord session;
  final List<AdminUserRecord> users;
  final VoidCallback onEditAccount;
  final VoidCallback onChangePassword;
  final VoidCallback onCreateAdmin;
  final VoidCallback onClearLoginRecords;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, yyyy HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.displayName} is currently authenticated.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text('@${session.username}'),
              const SizedBox(height: 6),
              Text(
                'Session started ${formatter.format(session.authenticatedAtUtc.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onEditAccount,
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Edit account'),
            ),
            OutlinedButton.icon(
              onPressed: onChangePassword,
              icon: const Icon(Icons.password_rounded),
              label: const Text('Change password'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateAdmin,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create admin'),
            ),
            OutlinedButton.icon(
              onPressed: onClearLoginRecords,
              icon: const Icon(Icons.history_toggle_off_rounded),
              label: const Text('Clear login records'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Configured admins',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        for (final user in users) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(user.displayName),
            subtitle: Text('@${user.username}'),
            trailing: Text(
              user.lastLoginAtUtc == null
                  ? 'Never signed in'
                  : formatter.format(user.lastLoginAtUtc!.toLocal()),
              textAlign: TextAlign.right,
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.activities});

  final List<AdminActivityRecord> activities;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    final visibleActivities = activities.take(12).toList(growable: false);

    if (visibleActivities.isEmpty) {
      return Text(
        'No local audit records have been written yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: [
        for (final activity in visibleActivities) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                child: Icon(_activityIcon(activity.type), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(activity.occurredAtUtc.toLocal())} • ${activity.actorUsername ?? 'system'} • ${activity.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((activity.itemCount ?? 0) > 0 ||
                        (activity.totalBytes ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${activity.itemCount ?? 0} item${(activity.itemCount ?? 0) == 1 ? '' : 's'} • ${_humanizeBytes(activity.totalBytes ?? 0)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  static IconData _activityIcon(AdminActivityType type) {
    switch (type) {
      case AdminActivityType.loginSuccess:
        return Icons.login_rounded;
      case AdminActivityType.loginFailure:
        return Icons.warning_amber_rounded;
      case AdminActivityType.logout:
        return Icons.logout_rounded;
      case AdminActivityType.userCreated:
        return Icons.person_add_alt_1_rounded;
      case AdminActivityType.passwordChanged:
        return Icons.password_rounded;
      case AdminActivityType.profileUpdated:
        return Icons.manage_accounts_rounded;
      case AdminActivityType.inventoryRefresh:
        return Icons.inventory_2_rounded;
      case AdminActivityType.warmCaches:
        return Icons.bolt_rounded;
      case AdminActivityType.clearCaches:
        return Icons.cleaning_services_rounded;
      case AdminActivityType.encryptionBatch:
        return Icons.lock_rounded;
      case AdminActivityType.verificationCodeGenerated:
        return Icons.verified_user_rounded;
      case AdminActivityType.verificationCodeRecordsCleared:
        return Icons.playlist_remove_rounded;
      case AdminActivityType.loginRecordsCleared:
        return Icons.history_toggle_off_rounded;
    }
  }
}

class _VerificationOperationsPanel extends StatelessWidget {
  const _VerificationOperationsPanel({
    required this.requestController,
    required this.generatedVerificationQr,
    required this.statusMessage,
    required this.statusIsError,
    required this.isGenerating,
    required this.isClearing,
    required this.activities,
    required this.onGenerate,
    required this.onClearRecords,
  });

  final TextEditingController requestController;
  final VerificationQrPayload? generatedVerificationQr;
  final String? statusMessage;
  final bool statusIsError;
  final bool isGenerating;
  final bool isClearing;
  final List<AdminActivityRecord> activities;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onClearRecords;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verificationActivities = activities
        .where(
          (record) =>
              record.type == AdminActivityType.verificationCodeGenerated,
        )
        .toList(growable: false);
    final dateBuckets = <String, int>{
      'Today': 0,
      'Yesterday': 0,
      'Tomorrow': 0,
      'Other dates': 0,
    };
    final featureCounts = <String, int>{};
    final contentTypeCounts = <String, int>{};
    for (final record in verificationActivities) {
      final bucket = _relativeDayBucket(record.occurredAtUtc);
      dateBuckets[bucket] = (dateBuckets[bucket] ?? 0) + 1;

      final featureKey = record.metadata?['feature'] ?? 'unknown';
      featureCounts[featureKey] = (featureCounts[featureKey] ?? 0) + 1;

      final contentCategory = record.metadata?['contentCategory'] ?? 'unknown';
      contentTypeCounts[contentCategory] =
          (contentTypeCounts[contentCategory] ?? 0) + 1;
    }

    final sortedFeatureCounts = featureCounts.entries.toList(growable: false)
      ..sort((left, right) => right.value.compareTo(left.value));
    final sortedContentTypeCounts = contentTypeCounts.entries.toList(
      growable: false,
    )..sort((left, right) => right.value.compareTo(left.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: requestController,
          decoration: const InputDecoration(
            labelText: 'Client request code',
            hintText: 'ERI-REQ1-...',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(isGenerating ? 'Generating...' : 'Generate admin QR'),
            ),
            OutlinedButton.icon(
              onPressed: isClearing ? null : onClearRecords,
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(isClearing ? 'Clearing...' : 'Clear records'),
            ),
          ],
        ),
        if (generatedVerificationQr != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last generated admin approval',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'A full-screen QR is shown immediately after generation so the client app can scan it from Settings.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  generatedVerificationQr!.verificationCode,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onGenerate(),
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: const Text('Regenerate and open QR'),
                    ),
                    Text(
                      'Issued ${DateFormat('MMM d, yyyy HH:mm').format(generatedVerificationQr!.issuedAtUtc.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (statusMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            statusMessage!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: statusIsError ? scheme.error : scheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _VerificationMetricBadge(
              label: 'Generated',
              value: '${verificationActivities.length}',
            ),
            _VerificationMetricBadge(
              label: 'Today',
              value: '${dateBuckets['Today'] ?? 0}',
            ),
            _VerificationMetricBadge(
              label: 'Yesterday',
              value: '${dateBuckets['Yesterday'] ?? 0}',
            ),
            _VerificationMetricBadge(
              label: 'Tomorrow',
              value: '${dateBuckets['Tomorrow'] ?? 0}',
            ),
            _VerificationMetricBadge(
              label: 'Other dates',
              value: '${dateBuckets['Other dates'] ?? 0}',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Feature distribution',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (sortedFeatureCounts.isEmpty)
          Text(
            'No verification QR approvals have been generated yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Column(
            children: [
              for (final entry in sortedFeatureCounts) ...[
                _VerificationCountRow(
                  label: ContentVerificationService.featureLabel(entry.key),
                  value: entry.value,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Content type distribution',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (sortedContentTypeCounts.isEmpty)
          Text(
            'No content-type breakdown is available yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Column(
            children: [
              for (final entry in sortedContentTypeCounts) ...[
                _VerificationCountRow(
                  label: _verificationContentLabel(entry.key),
                  value: entry.value,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }

  static String _relativeDayBucket(DateTime value) {
    final localValue = value.toLocal();
    final localDate = DateTime(
      localValue.year,
      localValue.month,
      localValue.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = localDate.difference(today).inDays;
    switch (difference) {
      case -1:
        return 'Yesterday';
      case 0:
        return 'Today';
      case 1:
        return 'Tomorrow';
      default:
        return 'Other dates';
    }
  }

  static String _verificationContentLabel(String value) {
    switch (value) {
      case 'reels':
        return 'Reels';
      case 'videoHighlights':
        return 'Video highlights';
      case 'videoNews':
        return 'Video news';
      case 'videoUpdates':
        return 'Video updates';
      case 'newsImages':
        return 'News images';
      case 'mixed':
        return 'Mixed pending content';
      case 'none':
        return 'No pending content';
      default:
        return value;
    }
  }
}

class _VerificationMetricBadge extends StatelessWidget {
  const _VerificationMetricBadge({required this.label, required this.value});

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
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _VerificationCountRow extends StatelessWidget {
  const _VerificationCountRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _DashboardLoadingPanel extends StatelessWidget {
  const _DashboardLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DashboardErrorPanel extends StatelessWidget {
  const _DashboardErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unable to inspect secure content',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncryptionImportPanel extends StatelessWidget {
  const _EncryptionImportPanel({
    required this.selectedSources,
    required this.selectedSourceRoot,
    required this.jobSnapshot,
    required this.destinationRoots,
    required this.jsonDestinationController,
    required this.imageDestinationController,
    required this.videoDestinationController,
    required this.reelsDestinationController,
    required this.overwriteExisting,
    required this.isEncrypting,
    required this.onApplyPreset,
    required this.onOverwriteChanged,
    required this.onRemoveAllByKind,
    required this.onAssignVideoCategory,
    required this.onRemoveSource,
    required this.onImport,
  });

  final List<_PendingSecureSource> selectedSources;
  final String? selectedSourceRoot;
  final SecureContentEncryptionJobSnapshot jobSnapshot;
  final SecureContentDestinationRoots destinationRoots;
  final TextEditingController jsonDestinationController;
  final TextEditingController imageDestinationController;
  final TextEditingController videoDestinationController;
  final TextEditingController reelsDestinationController;
  final bool overwriteExisting;
  final bool isEncrypting;
  final void Function(SecureContentImportDestinationSlot slot, String value)
  onApplyPreset;
  final ValueChanged<bool> onOverwriteChanged;
  final Future<void> Function(SecureContentImportDestinationSlot slot)
  onRemoveAllByKind;
  final void Function(_PendingSecureSource, SecureVideoImportCategory)
  onAssignVideoCategory;
  final ValueChanged<_PendingSecureSource> onRemoveSource;
  final VoidCallback onImport;

  static const Map<SecureContentImportDestinationSlot, List<String>>
  _presetsBySlot = <SecureContentImportDestinationSlot, List<String>>{
    SecureContentImportDestinationSlot.json: <String>[
      'json',
      'imports/json',
      'catalog',
    ],
    SecureContentImportDestinationSlot.image: <String>[
      'news',
      'teams',
      'players',
      'images',
    ],
    SecureContentImportDestinationSlot.video: <String>[
      'highlights',
      'video-news',
      'updates',
      'video',
    ],
    SecureContentImportDestinationSlot.reels: <String>[
      'reels',
      'shorts',
      'short-videos',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final jsonCount =
        selectedSources
            .where((item) => item.kind == SecureContentKind.json)
            .length;
    final imageCount =
        selectedSources
            .where((item) => item.kind == SecureContentKind.image)
            .length;
    final videoCount =
        selectedSources
            .where(
              (item) =>
                  item.kind == SecureContentKind.video &&
                  item.effectiveVideoCategory ==
                      SecureVideoImportCategory.video,
            )
            .length;
    final reelsCount =
        selectedSources
            .where(
              (item) =>
                  item.kind == SecureContentKind.video &&
                  item.effectiveVideoCategory ==
                      SecureVideoImportCategory.reels,
            )
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
          const SizedBox(height: 8),
          Text(
            'Video and Reels now stay separate. Use the dedicated pickers for explicit imports, or reassign each pending video in the review table before encryption.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _DestinationPresetEditor(
            slot: SecureContentImportDestinationSlot.json,
            label: 'JSON destination',
            hintText: 'json or imports/json',
            controller: jsonDestinationController,
            presets: _presetsBySlot[SecureContentImportDestinationSlot.json]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          _DestinationPresetEditor(
            slot: SecureContentImportDestinationSlot.image,
            label: 'Image destination',
            hintText: 'news or teams',
            controller: imageDestinationController,
            presets: _presetsBySlot[SecureContentImportDestinationSlot.image]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          _DestinationPresetEditor(
            slot: SecureContentImportDestinationSlot.video,
            label: 'Video destination',
            hintText: 'highlights, video-news, updates, or video',
            controller: videoDestinationController,
            presets: _presetsBySlot[SecureContentImportDestinationSlot.video]!,
            onApplyPreset: onApplyPreset,
          ),
          const SizedBox(height: 10),
          _DestinationPresetEditor(
            slot: SecureContentImportDestinationSlot.reels,
            label: 'Reels destination',
            hintText: 'reels, shorts, or short-videos',
            controller: reelsDestinationController,
            presets: _presetsBySlot[SecureContentImportDestinationSlot.reels]!,
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
              _StatChip(label: 'Reels', value: '$reelsCount'),
            ],
          ),
          if (videoCount > 0 || reelsCount > 0) ...[
            const SizedBox(height: 12),
            _PendingVideoRoutingSummary(
              videoCount: videoCount,
              reelsCount: reelsCount,
              videoDestination: destinationRoots.video,
              reelsDestination: destinationRoots.reels,
            ),
          ],
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
                              onRemoveAllByKind(
                                SecureContentImportDestinationSlot.json,
                              );
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
                              onRemoveAllByKind(
                                SecureContentImportDestinationSlot.image,
                              );
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
                              onRemoveAllByKind(
                                SecureContentImportDestinationSlot.video,
                              );
                            },
                  ),
                if (reelsCount > 0)
                  ActionChip(
                    avatar: const Icon(Icons.movie_filter_outlined, size: 18),
                    label: Text('Remove all reels ($reelsCount)'),
                    onPressed:
                        isEncrypting
                            ? null
                            : () {
                              onRemoveAllByKind(
                                SecureContentImportDestinationSlot.reels,
                              );
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
              destinationRoots: destinationRoots,
              isEncrypting: isEncrypting,
              onAssignVideoCategory: onAssignVideoCategory,
              onRemoveSource: onRemoveSource,
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed:
                selectedSources.isEmpty || isEncrypting ? null : onImport,
            icon: const Icon(Icons.lock_rounded),
            label: Text(
              isEncrypting
                  ? 'Encrypting and importing...'
                  : 'Encrypt into daylySport',
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationPresetEditor extends StatelessWidget {
  const _DestinationPresetEditor({
    required this.slot,
    required this.label,
    required this.hintText,
    required this.controller,
    required this.presets,
    required this.onApplyPreset,
  });

  final SecureContentImportDestinationSlot slot;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final List<String> presets;
  final void Function(SecureContentImportDestinationSlot slot, String value)
  onApplyPreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: hintText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              ActionChip(
                label: Text(preset),
                onPressed: () => onApplyPreset(slot, preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingVideoRoutingSummary extends StatelessWidget {
  const _PendingVideoRoutingSummary({
    required this.videoCount,
    required this.reelsCount,
    required this.videoDestination,
    required this.reelsDestination,
  });

  final int videoCount;
  final int reelsCount;
  final String videoDestination;
  final String reelsDestination;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _RoutingSummaryCard(
          label: 'Video group',
          count: videoCount,
          destination: videoDestination,
          icon: Icons.video_library_outlined,
        ),
        _RoutingSummaryCard(
          label: 'Reels group',
          count: reelsCount,
          destination: reelsDestination,
          icon: Icons.movie_filter_outlined,
        ),
      ],
    );
  }
}

class _RoutingSummaryCard extends StatelessWidget {
  const _RoutingSummaryCard({
    required this.label,
    required this.count,
    required this.destination,
    required this.icon,
  });

  final String label;
  final int count;
  final String destination;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '$count pending item${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            destination.isEmpty
                ? 'Destination required'
                : 'Output: $destination',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SelectedSourcesReviewTable extends StatelessWidget {
  const _SelectedSourcesReviewTable({
    required this.selectedSources,
    required this.jobSnapshot,
    required this.destinationRoots,
    required this.isEncrypting,
    required this.onAssignVideoCategory,
    required this.onRemoveSource,
  });

  final List<_PendingSecureSource> selectedSources;
  final SecureContentEncryptionJobSnapshot jobSnapshot;
  final SecureContentDestinationRoots destinationRoots;
  final bool isEncrypting;
  final void Function(_PendingSecureSource, SecureVideoImportCategory)
  onAssignVideoCategory;
  final ValueChanged<_PendingSecureSource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    final progressByRequestId = <String, SecureContentEncryptionJobItemState>{
      for (final item in jobSnapshot.items) item.requestId: item,
    };
    final orderedSources = List<_PendingSecureSource>.of(selectedSources)
      ..sort((left, right) {
        final kindCompare = left.kind.index.compareTo(right.kind.index);
        if (kindCompare != 0) {
          return kindCompare;
        }
        final categoryCompare = left.effectiveVideoCategory.index.compareTo(
          right.effectiveVideoCategory.index,
        );
        if (categoryCompare != 0) {
          return categoryCompare;
        }
        return left.relativeOutputPath.toLowerCase().compareTo(
          right.relativeOutputPath.toLowerCase(),
        );
      });

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
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Source')),
              DataColumn(label: Text('Encrypted output')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Progress')),
              DataColumn(label: Text('Remove')),
            ],
            rows: orderedSources
                .map((source) {
                  final itemState = progressByRequestId[source.requestId];
                  final outputPath = destinationRoots.buildOutputPath(
                    kind: source.kind,
                    relativeOutputPath: source.relativeOutputPath,
                    videoCategory: source.effectiveVideoCategory,
                  );
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
                        source.kind == SecureContentKind.video
                            ? DropdownButtonHideUnderline(
                              child: DropdownButton<SecureVideoImportCategory>(
                                value: source.effectiveVideoCategory,
                                items: SecureVideoImportCategory.values
                                    .map(
                                      (category) => DropdownMenuItem<
                                        SecureVideoImportCategory
                                      >(
                                        value: category,
                                        child: Text(category.label),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged:
                                    isEncrypting
                                        ? null
                                        : (value) {
                                          if (value != null) {
                                            onAssignVideoCategory(
                                              source,
                                              value,
                                            );
                                          }
                                        },
                              ),
                            )
                            : Text(
                              destinationRoots.slotFor(kind: source.kind).label,
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
                })
                .toList(growable: false),
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

  static String _encryptedPreviewPath(
    String logicalPath,
    SecureContentKind kind,
  ) {
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
    final bytesLabel =
        itemState.totalBytes > 0
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
            snapshot.isRunning
                ? 'Encryption in progress'
                : 'Last encryption batch',
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
              _StatChip(
                label: 'Completed',
                value: '${snapshot.completedFiles}',
              ),
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
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
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
    required this.plainJsonBytes,
    required this.encryptedJsonBytes,
    required this.plainImageBytes,
    required this.encryptedImageBytes,
    required this.plainVideoBytes,
    required this.encryptedVideoBytes,
    required this.encryptedDateBuckets,
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
  final int plainJsonBytes;
  final int encryptedJsonBytes;
  final int plainImageBytes;
  final int encryptedImageBytes;
  final int plainVideoBytes;
  final int encryptedVideoBytes;
  final List<SecureContentDateBucket> encryptedDateBuckets;
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

  int get totalEncryptedBytes =>
      encryptedJsonBytes + encryptedImageBytes + encryptedVideoBytes;

  int get totalPlainBytes => plainJsonBytes + plainImageBytes + plainVideoBytes;

  int get plainFiles => plainJsonFiles + plainImageFiles + plainVideoFiles;

  int get encryptedCoveragePercent {
    if (supportedFiles == 0) {
      return 0;
    }
    return ((encryptedFiles / supportedFiles) * 100).round();
  }
}

class SecureContentDateBucket {
  const SecureContentDateBucket({
    required this.dayUtc,
    required this.encryptedFiles,
    required this.encryptedBytes,
  });

  final DateTime dayUtc;
  final int encryptedFiles;
  final int encryptedBytes;
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
  var plainJsonBytes = 0;
  var encryptedJsonBytes = 0;
  var plainImageBytes = 0;
  var encryptedImageBytes = 0;
  var plainVideoBytes = 0;
  var encryptedVideoBytes = 0;
  final sampleEncryptedPaths = <String>[];
  final samplePlainPaths = <String>[];
  final encryptedDateAccumulator = <DateTime, _EncryptedDateAccumulator>{};

  if (rootDirectory.existsSync()) {
    for (final entity in rootDirectory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }

      totalFiles += 1;
      final fileSizeBytes = entity.lengthSync();
      final modifiedAt = entity.lastModifiedSync().toUtc();

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
            encryptedJsonBytes += fileSizeBytes;
          } else {
            plainJsonFiles += 1;
            plainJsonBytes += fileSizeBytes;
          }
        case SecureContentKind.image:
          if (descriptor.isEncrypted) {
            encryptedImageFiles += 1;
            encryptedImageBytes += fileSizeBytes;
          } else {
            plainImageFiles += 1;
            plainImageBytes += fileSizeBytes;
          }
        case SecureContentKind.video:
          if (descriptor.isEncrypted) {
            encryptedVideoFiles += 1;
            encryptedVideoBytes += fileSizeBytes;
          } else {
            plainVideoFiles += 1;
            plainVideoBytes += fileSizeBytes;
          }
        case SecureContentKind.other:
          otherFiles += 1;
      }

      if (descriptor.isEncrypted &&
          descriptor.kind != SecureContentKind.other) {
        final dayUtc = DateTime.utc(
          modifiedAt.year,
          modifiedAt.month,
          modifiedAt.day,
        );
        final accumulator = encryptedDateAccumulator.putIfAbsent(
          dayUtc,
          () => _EncryptedDateAccumulator(dayUtc: dayUtc),
        );
        accumulator.encryptedFiles += 1;
        accumulator.encryptedBytes += fileSizeBytes;
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
    plainJsonBytes: plainJsonBytes,
    encryptedJsonBytes: encryptedJsonBytes,
    plainImageBytes: plainImageBytes,
    encryptedImageBytes: encryptedImageBytes,
    plainVideoBytes: plainVideoBytes,
    encryptedVideoBytes: encryptedVideoBytes,
    encryptedDateBuckets: encryptedDateAccumulator.values
        .map(
          (entry) => SecureContentDateBucket(
            dayUtc: entry.dayUtc,
            encryptedFiles: entry.encryptedFiles,
            encryptedBytes: entry.encryptedBytes,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => right.dayUtc.compareTo(left.dayUtc)),
    sampleEncryptedPaths: sampleEncryptedPaths,
    samplePlainPaths: samplePlainPaths,
  );
}

class _EncryptedDateAccumulator {
  _EncryptedDateAccumulator({required this.dayUtc});

  final DateTime dayUtc;
  int encryptedFiles = 0;
  int encryptedBytes = 0;
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
                  label: 'Encrypted size',
                  value: _humanizeBytes(inventory.totalEncryptedBytes),
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
              encryptedBytes: inventory.encryptedJsonBytes,
              plainBytes: inventory.plainJsonBytes,
            ),
            const SizedBox(height: 10),
            _BreakdownRow(
              label: 'Images',
              encryptedCount: inventory.encryptedImageFiles,
              plainCount: inventory.plainImageFiles,
              encryptedBytes: inventory.encryptedImageBytes,
              plainBytes: inventory.plainImageBytes,
            ),
            const SizedBox(height: 10),
            _BreakdownRow(
              label: 'Video',
              encryptedCount: inventory.encryptedVideoFiles,
              plainCount: inventory.plainVideoFiles,
              encryptedBytes: inventory.encryptedVideoBytes,
              plainBytes: inventory.plainVideoBytes,
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
    required this.encryptedBytes,
    required this.plainBytes,
  });

  final String label;
  final int encryptedCount;
  final int plainCount;
  final int encryptedBytes;
  final int plainBytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        Text('Encrypted $encryptedCount • ${_humanizeBytes(encryptedBytes)}'),
        const SizedBox(width: 12),
        Text('Plain $plainCount • ${_humanizeBytes(plainBytes)}'),
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
