import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/secure_content_encryption_job_manager.dart';
import 'package:eri_sports/features/admin/data/admin_models.dart';
import 'package:eri_sports/features/admin/data/admin_providers.dart';
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
const adminDashboardCoverageTabKey = Key('adminDashboardCoverageTab');
const adminDashboardOperationsTabKey = Key('adminDashboardOperationsTab');
const adminDashboardActivityTabKey = Key('adminDashboardActivityTab');
const adminCreateUserDisplayNameFieldKey = Key(
  'adminCreateUserDisplayNameField',
);
const adminCreateUserUsernameFieldKey = Key('adminCreateUserUsernameField');
const adminCreateUserPasswordFieldKey = Key('adminCreateUserPasswordField');
const adminCreateUserConfirmPasswordFieldKey = Key(
  'adminCreateUserConfirmPasswordField',
);
const adminCreateUserSubmitButtonKey = Key('adminCreateUserSubmitButton');
const adminChangePasswordCurrentFieldKey = Key(
  'adminChangePasswordCurrentField',
);
const adminChangePasswordNewFieldKey = Key('adminChangePasswordNewField');
const adminChangePasswordConfirmFieldKey = Key(
  'adminChangePasswordConfirmField',
);
const adminChangePasswordSubmitButtonKey = Key(
  'adminChangePasswordSubmitButton',
);

typedef SecureContentInventoryScanDelegate =
    Future<SecureContentInventory> Function(String rootPath);

SecureContentInventoryScanDelegate secureContentInventoryScanDelegate =
    scanSecureContentInventoryInIsolate;

const Set<String> _knownVideoImportRootSegments = <String>{
  'reels',
  'shorts',
  'short_videos',
  'short-videos',
  'highlights',
  'highlight',
  'video-news',
  'video_news',
  'news-videos',
  'news_videos',
  'updates',
  'update',
};

const Set<String> _knownVideoImportRootPrefixes = <String>{
  'video/news',
  'videos/news',
};

String resolveSecureImportRelativeOutputPath({
  required String relativeOutputPath,
  required SecureContentKind kind,
  required String destinationRoot,
}) {
  final normalizedRelativePath = _normalizeSecureImportPath(relativeOutputPath);
  final normalizedDestinationRoot = _normalizeSecureImportPath(destinationRoot);

  if (normalizedDestinationRoot.isEmpty || normalizedRelativePath.isEmpty) {
    return normalizedRelativePath;
  }

  if (normalizedRelativePath == normalizedDestinationRoot ||
      normalizedRelativePath.startsWith('$normalizedDestinationRoot/')) {
    return normalizedRelativePath;
  }

  if (kind == SecureContentKind.video &&
      _hasKnownVideoImportRoot(normalizedRelativePath)) {
    return normalizedRelativePath;
  }

  return p
      .join(normalizedDestinationRoot, normalizedRelativePath)
      .replaceAll('\\', '/');
}

bool secureContentDestinationRootRequired(SecureContentKind kind) {
  return kind != SecureContentKind.video;
}

String _normalizeSecureImportPath(String rawPath) {
  final normalized = p
      .normalize(rawPath.trim().replaceAll('\\', '/'))
      .replaceAll('\\', '/');
  final sanitized = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty && segment != '.' && segment != '..')
      .join('/');
  return sanitized;
}

bool _hasKnownVideoImportRoot(String relativeOutputPath) {
  final segments = relativeOutputPath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) {
    return false;
  }

  if (_knownVideoImportRootSegments.contains(segments.first.toLowerCase())) {
    return true;
  }

  if (segments.length < 2) {
    return false;
  }

  final rootPrefix = '${segments[0].toLowerCase()}/${segments[1].toLowerCase()}';
  return _knownVideoImportRootPrefixes.contains(rootPrefix);
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

  SecureContentInventory? _inventory;
  String? _errorMessage;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isRefreshing = false;
  bool _isWarmingCaches = false;
  bool _isClearingCaches = false;
  bool _isPickingSources = false;
  bool _isEncrypting = false;
  bool _requestedInitialInventoryLoad = false;
  bool _isGeneratingVerificationCode = false;
  bool _isClearingVerificationRecords = false;
  bool _overwriteExisting = true;
  String? _selectedSourceRoot;
  String? _verificationMessage;
  bool _verificationMessageIsError = false;
  String _coverageQuery = '';
  String _coverageStatusFilter = 'all';
  SecureContentKind? _coverageKindFilter;
  int? _activityDaysFilter;
  String? _activityActorFilter;
  AdminActivityType? _activityTypeFilter;
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
    VerificationQrPayload? _generatedVerificationQr;

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
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _jsonDestinationController.dispose();
    _imageDestinationController.dispose();
    _videoDestinationController.dispose();
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
      final inventory = await secureContentInventoryScanDelegate(
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

    final confirmed = await _confirmDangerousAction(
      title: 'Clear decrypted caches?',
      message:
          'This removes decrypted runtime cache files and may slow the next secure content open. Encrypted source files will not be changed.',
      confirmLabel: 'Clear caches',
    );
    if (confirmed != true) {
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
      _statusMessage =
          'Removed $removedCount ${_kindLabel(kind)} item${removedCount == 1 ? '' : 's'} from the import list.';
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
      .where(
        (kind) =>
          secureContentDestinationRootRequired(kind) &&
          (destinationByKind[kind] ?? '').isEmpty,
      )
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
      final selectedBytes = _selectedSources.fold<int>(0, (total, source) {
        try {
          return total + File(source.sourcePath).lengthSync();
        } catch (_) {
          return total;
        }
      });
      final selectedKinds =
          _selectedSources.map((source) => source.kind).toSet();
      final category =
          selectedKinds.length == 1
              ? _kindLabel(selectedKinds.first).toLowerCase()
              : 'mixed';
      final requests = _selectedSources
          .map(
            (source) => SecureContentEncryptionRequest(
              requestId: source.requestId,
              sourcePath: source.sourcePath,
              relativeOutputPath: resolveSecureImportRelativeOutputPath(
                relativeOutputPath: source.relativeOutputPath,
                kind: source.kind,
                destinationRoot: destinationByKind[source.kind] ?? '',
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
                      key: adminCreateUserDisplayNameFieldKey,
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: adminCreateUserUsernameFieldKey,
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: adminCreateUserPasswordFieldKey,
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
                      key: adminCreateUserConfirmPasswordFieldKey,
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
                  key: adminCreateUserSubmitButtonKey,
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
                      key: adminChangePasswordCurrentFieldKey,
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
                      key: adminChangePasswordNewFieldKey,
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
                      key: adminChangePasswordConfirmFieldKey,
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
                  key: adminChangePasswordSubmitButtonKey,
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

    setState(() {
      _isGeneratingVerificationCode = true;
      _verificationMessage = null;
      _verificationMessageIsError = false;
    });

    try {
      final verificationQr =
          ref.read(contentVerificationServiceProvider).generateVerificationQrPayload();
      await _recordDashboardActivity(
        type: AdminActivityType.verificationCodeGenerated,
        summary:
            'Generated ${ContentVerificationService.featureLabel(verificationQr.feature).toLowerCase()} direct verification QR approval.',
        category: 'verification',
        metadata: <String, String>{
          'feature': verificationQr.feature,
          'contentCategory': verificationQr.feature,
          'verificationMode': 'direct_qr',
          'verificationCode': verificationQr.verificationCode,
          'verificationQrIssuedAtUtc':
              verificationQr.issuedAtUtc.toIso8601String(),
          'verificationQrExpiresAtUtc':
              verificationQr.expiresAtUtc.toIso8601String(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _generatedVerificationQr = verificationQr;
        _verificationMessage =
            'Verification QR generated for ${ContentVerificationService.featureLabel(verificationQr.feature)}.';
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
            'This removes persisted verification QR generation records from the local audit history.',
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
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        )
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
    return _contentKindLabel(kind);
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

  Future<bool?> _confirmDangerousAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  void _goToTab(int index) {
    DefaultTabController.maybeOf(context)?.animateTo(index);
  }

  List<SecureContentInventoryItem> _filteredCoverageItems(
    SecureContentInventory inventory,
  ) {
    final query = _coverageQuery.trim().toLowerCase();
    final filtered = inventory.items
        .where((item) {
          if (_coverageKindFilter != null && item.kind != _coverageKindFilter) {
            return false;
          }
          switch (_coverageStatusFilter) {
            case 'encrypted':
              if (!item.isEncrypted) {
                return false;
              }
            case 'plain':
              if (item.isEncrypted) {
                return false;
              }
            case 'warning':
              if (item.isEncrypted) {
                return false;
              }
            case 'all':
              break;
            default:
              break;
          }
          if (query.isEmpty) {
            return true;
          }
          return item.relativePath.toLowerCase().contains(query) ||
              item.kind.name.toLowerCase().contains(query) ||
              (item.isEncrypted ? 'encrypted' : 'plain').contains(query);
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      if (left.isEncrypted != right.isEncrypted) {
        return left.isEncrypted ? 1 : -1;
      }
      final modifiedCompare = right.modifiedAtUtc.compareTo(left.modifiedAtUtc);
      if (modifiedCompare != 0) {
        return modifiedCompare;
      }
      return left.relativePath.toLowerCase().compareTo(
        right.relativePath.toLowerCase(),
      );
    });
    return filtered;
  }

  List<AdminActivityRecord> _filteredActivities(
    List<AdminActivityRecord> activities,
  ) {
    final cutoff =
        _activityDaysFilter == null
            ? null
            : DateTime.now().toUtc().subtract(
              Duration(days: _activityDaysFilter!),
            );
    final filtered = activities
        .where((activity) {
          if (cutoff != null && activity.occurredAtUtc.isBefore(cutoff)) {
            return false;
          }
          if (_activityActorFilter != null) {
            final actor = activity.actorUsername ?? 'system';
            if (actor != _activityActorFilter) {
              return false;
            }
          }
          if (_activityTypeFilter != null &&
              activity.type != _activityTypeFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    filtered.sort(
      (left, right) => right.occurredAtUtc.compareTo(left.occurredAtUtc),
    );
    return filtered;
  }

  Widget _buildDashboardTab({
    required List<Widget> Function(double maxWidth) childrenBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 1480.0);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: maxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: childrenBuilder(maxWidth),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildLoadingChildren() {
    if (_isRefreshing) {
      return const <Widget>[_DashboardLoadingPanel()];
    }
    if (_errorMessage != null) {
      return <Widget>[_DashboardErrorPanel(message: _errorMessage!)];
    }
    return const <Widget>[_DashboardLoadingPanel()];
  }

  Widget _buildHomeTab({
    required AdminSessionRecord session,
    required SecureContentInventory? inventory,
    required _SecureContentDashboardSnapshot? snapshot,
  }) {
    return _buildDashboardTab(
      childrenBuilder: (maxWidth) {
        if (snapshot == null) {
          return _buildLoadingChildren();
        }

        return <Widget>[
          _DashboardHeroCard(
            session: session,
            inventory: inventory,
            isRefreshing: _isRefreshing,
            isWarmingCaches: _isWarmingCaches,
            onRefresh: _refreshInventory,
            onWarmCaches: _warmCaches,
            onOpenCoverage: () => _goToTab(1),
            onOpenOperations: () => _goToTab(2),
            onLogout: _logout,
          ),
          const SizedBox(height: 18),
          _OverviewMetricsGrid(snapshot: snapshot),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                key: adminDashboardOverviewKey,
                title: 'Inventory health',
                subtitle:
                    'Scan critical security status first: encryption coverage, plain-file exposure, and the latest scan outcome.',
                child: _OverviewHealthPanel(
                  snapshot: snapshot,
                  jobSnapshot: _jobSnapshot,
                ),
              ),
              _SectionCard(
                title: 'Priority alerts',
                subtitle:
                    'Warnings and failures are surfaced here before lower-priority operational detail.',
                child: _AlertsPanel(
                  inventory: snapshot.inventory,
                  errorMessage: _errorMessage,
                  jobSnapshot: _jobSnapshot,
                ),
              ),
              _SectionCard(
                title: 'Operational context',
                subtitle:
                    'Operator, maintenance, and workflow state are grouped into one concise desktop briefing.',
                child: _OperationalHighlightsPanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Quick actions',
                subtitle:
                    'Move directly into scan, cache prep, coverage review, or encryption workflows without losing context.',
                child: _OverviewActionPanel(
                  isRefreshing: _isRefreshing,
                  isWarmingCaches: _isWarmingCaches,
                  isEncrypting: _isEncrypting,
                  onRefresh: _refreshInventory,
                  onWarmCaches: _warmCaches,
                  onOpenCoverage: () => _goToTab(1),
                  onOpenOperations: () => _goToTab(2),
                  onOpenSync: () => context.push('/sync'),
                ),
              ),
            ],
          ),
        ];
      },
    );
  }

  Widget _buildCoverageTab(_SecureContentDashboardSnapshot? snapshot) {
    return _buildDashboardTab(
      childrenBuilder: (maxWidth) {
        if (snapshot == null) {
          return _buildLoadingChildren();
        }

        final filteredItems = _filteredCoverageItems(snapshot.inventory);
        final visibleItems = filteredItems.take(60).toList(growable: false);

        return <Widget>[
          _CoverageToolbar(
            query: _coverageQuery,
            statusFilter: _coverageStatusFilter,
            kindFilter: _coverageKindFilter,
            onQueryChanged: (value) {
              setState(() {
                _coverageQuery = value;
              });
            },
            onStatusFilterChanged: (value) {
              setState(() {
                _coverageStatusFilter = value;
              });
            },
            onKindFilterChanged: (value) {
              setState(() {
                _coverageKindFilter = value;
              });
            },
          ),
          const SizedBox(height: 18),
          _CoverageSummaryGrid(snapshot: snapshot),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Inventory review',
            subtitle:
                'Searchable secure content inventory with clear plain-vs-encrypted status so remediation can be prioritized quickly.',
            child: _CoverageInventoryTable(
              items: visibleItems,
              totalItemCount: filteredItems.length,
              totalInventoryCount: snapshot.inventory.items.length,
              onOpenOperations: () => _goToTab(2),
            ),
          ),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                title: 'Coverage by type',
                subtitle:
                    'Desktop-ready breakdown of encrypted and plain exposure across JSON, image, and video assets.',
                child: _InventoryBreakdownCard(inventory: snapshot.inventory),
              ),
              _SectionCard(
                title: 'Encrypted share',
                subtitle:
                    'Relative share of encrypted items by content type to support fast visual scanning during audit review.',
                child: _CategoryStatisticsPanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Inventory overview',
                subtitle:
                    'Coverage, root location, and scan freshness remain visible during desktop review.',
                child: _InventoryOverviewCard(inventory: snapshot.inventory),
              ),
              _SectionCard(
                title: 'Recent protected volume',
                subtitle:
                    'Recent encrypted file activity and payload distribution to support audit review and capacity planning.',
                child: _DateAndSizePanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Detected file samples',
                subtitle:
                    'Use representative encrypted and plain paths to verify naming, destination choice, and scan accuracy.',
                child: _InventorySamplesCard(inventory: snapshot.inventory),
              ),
            ],
          ),
        ];
      },
    );
  }

  Widget _buildOperationsTab(SecureContentInventory? inventory) {
    return _buildDashboardTab(
      childrenBuilder: (maxWidth) {
        return <Widget>[
          _OperationsBanner(
            snapshot: _jobSnapshot,
            selectedSourceCount: _selectedSources.length,
          ),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                title: 'Queue status',
                subtitle:
                    'Monitor the active batch, queued work, and the next operator action without leaving the Operations tab.',
                child: _OperationsQueuePanel(
                  snapshot: _jobSnapshot,
                  selectedSourceCount: _selectedSources.length,
                ),
              ),
              _SectionCard(
                title: 'System health',
                subtitle:
                    'Track throughput, failure count, and secure storage posture during imports and maintenance windows.',
                child: _OperationsHealthPanel(
                  inventory: inventory,
                  snapshot: _jobSnapshot,
                ),
              ),
              _SectionCard(
                title: 'Encryption workspace',
                subtitle:
                    'Select plain files or folders and import them into encrypted daylySport destinations.',
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
                                  : _pickFiles,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _isPickingSources
                                ? 'Opening picker...'
                                : 'Browse files',
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
                          SecureContentKind.image =>
                            _imageDestinationController,
                          SecureContentKind.video =>
                            _videoDestinationController,
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
              _SectionCard(
                title: 'Verification QR operations',
                subtitle:
                    'Generate direct admin QR approvals with no client request-code transfer, then let the client app complete verification by scanning them.',
                child: _VerificationOperationsPanel(
                  generatedVerificationQr: _generatedVerificationQr,
                  statusMessage: _verificationMessage,
                  statusIsError: _verificationMessageIsError,
                  isGenerating: _isGeneratingVerificationCode,
                  isClearing: _isClearingVerificationRecords,
                  activities: ref
                      .watch(adminActivityServiceProvider)
                      .records
                      .toList(growable: false),
                  onGenerate: _generateVerificationQr,
                  onClearRecords: _clearVerificationRecords,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Destructive actions',
            subtitle:
                'These actions affect decrypted runtime data or audit history and always require confirmation.',
            child: _OperationsDangerZone(
              isBusy: _isClearingCaches || _isWarmingCaches || _isEncrypting,
              onClearCaches: _clearCaches,
              onClearLoginRecords: _clearLoginRecords,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildActivityTab({
    required SecureContentInventory? inventory,
    required _SecureContentDashboardSnapshot? snapshot,
    required List<AdminActivityRecord> activities,
  }) {
    return _buildDashboardTab(
      childrenBuilder: (maxWidth) {
        if (snapshot == null) {
          return _buildLoadingChildren();
        }

        final filteredActivities = _filteredActivities(activities);
        final actorOptions = <String>{
          for (final activity in activities) activity.actorUsername ?? 'system',
        }.toList(growable: false)..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );

        return <Widget>[
          _ActivityFiltersPanel(
            daysFilter: _activityDaysFilter,
            actorFilter: _activityActorFilter,
            typeFilter: _activityTypeFilter,
            actorOptions: actorOptions,
            onDaysFilterChanged: (value) {
              setState(() {
                _activityDaysFilter = value;
              });
            },
            onActorFilterChanged: (value) {
              setState(() {
                _activityActorFilter = value;
              });
            },
            onTypeFilterChanged: (value) {
              setState(() {
                _activityTypeFilter = value;
              });
            },
          ),
          const SizedBox(height: 18),
          _ActivitySummaryGrid(activities: filteredActivities),
          const SizedBox(height: 18),
          _SectionCard(
            key: adminDashboardRecentActivityKey,
            title: 'Real-time logs',
            subtitle:
                'Filterable local audit records for authentication, inventory, maintenance, and encryption jobs.',
            child: _ActivityTablePanel(activities: filteredActivities),
          ),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                key: adminDashboardUserActivityKey,
                title: 'User activity',
                subtitle:
                    'Per-operator activity volume, import footprint, and recent sign-in behavior.',
                child: _UserActivityPanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Login records',
                subtitle:
                    'Authentication-focused entries remain visible separately for faster security review.',
                child: _LoginRecordsPanel(activities: filteredActivities),
              ),
              _SectionCard(
                title: 'Audit readiness',
                subtitle:
                    'A quick compliance-oriented read on recent activity volume, failures, and encryption throughput.',
                child: _AuditReadinessPanel(
                  snapshot: snapshot,
                  activities: filteredActivities,
                  inventory: inventory,
                ),
              ),
              _SectionCard(
                title: 'Activity digest',
                subtitle:
                    'Narrative feed for operators who prefer a concise chronological list over the structured log table.',
                child: _RecentActivityPanel(activities: filteredActivities),
              ),
            ],
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authService = ref.watch(adminAuthServiceProvider);
    final activityService = ref.watch(adminActivityServiceProvider);
    final session = authService.currentSession;
    final inventory = _inventory;
    final activities = activityService.records.toList(growable: false);
    final snapshot =
        session != null && inventory != null
            ? _SecureContentDashboardSnapshot(
              inventory: inventory,
              users: authService.users.toList(growable: false),
              activities: activities,
              currentSession: session,
            )
            : null;

    if (session != null && !_requestedInitialInventoryLoad) {
      _requestedInitialInventoryLoad = true;
      Future<void>.microtask(() => _refreshInventory(recordActivity: false));
    }

    if (session == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.03),
          scheme.surface,
        ),
        appBar: AppBar(
          scrolledUnderElevation: 0,
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
        ),
        body: Column(
          children: [
            _DashboardWorkspaceHeader(
              inventory: inventory,
              jobSnapshot: _jobSnapshot,
            ),
            const _DashboardTabBar(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildHomeTab(
                    session: session,
                    inventory: inventory,
                    snapshot: snapshot,
                  ),
                  _buildCoverageTab(snapshot),
                  _buildOperationsTab(inventory),
                  _buildActivityTab(
                    inventory: inventory,
                    snapshot: snapshot,
                    activities: activities,
                  ),
                ],
              ),
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
  });

  final String requestId;
  final String sourcePath;
  final String relativeOutputPath;
  final SecureContentKind kind;
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

  AdminActivityRecord? get lastMaintenanceActivity {
    for (final activity in activities) {
      if (activity.type == AdminActivityType.inventoryRefresh ||
          activity.type == AdminActivityType.warmCaches ||
          activity.type == AdminActivityType.clearCaches) {
        return activity;
      }
    }
    return null;
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
    required this.isWarmingCaches,
    required this.onRefresh,
    required this.onWarmCaches,
    required this.onOpenCoverage,
    required this.onOpenOperations,
    required this.onLogout,
  });

  final AdminSessionRecord session;
  final SecureContentInventory? inventory;
  final bool isRefreshing;
  final bool isWarmingCaches;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onWarmCaches;
  final VoidCallback onOpenCoverage;
  final VoidCallback onOpenOperations;
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
            scheme.primary.withValues(alpha: 0.15),
            scheme.surfaceContainerHighest,
            scheme.tertiary.withValues(alpha: 0.16),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                        'Secure content operations with scan-first visibility and remediation-ready actions',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Signed in as ${session.displayName} (${session.username}). Review environment health, scan coverage gaps, prepare runtime caches, and move directly into encryption or audit workflows without losing context.',
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
                        isRefreshing ? 'Running scan...' : 'Run scan',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          isRefreshing || isWarmingCaches ? null : onWarmCaches,
                      icon: const Icon(Icons.bolt_rounded),
                      label: Text(
                        isWarmingCaches ? 'Warming cache...' : 'Warm cache',
                      ),
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
                _HeroChip(
                  label: 'Plain files',
                  value:
                      inventoryData == null
                          ? 'Pending'
                          : '${inventoryData.plainFiles}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenCoverage,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Review coverage'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenOperations,
                  icon: const Icon(Icons.settings_input_component_rounded),
                  label: const Text('Open operations'),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
  const _OverviewMetricsGrid({required this.snapshot});

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(metric.icon, color: scheme.primary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'KPI',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
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

class _DashboardWorkspaceHeader extends StatelessWidget {
  const _DashboardWorkspaceHeader({
    required this.inventory,
    required this.jobSnapshot,
  });

  final SecureContentInventory? inventory;
  final SecureContentEncryptionJobSnapshot jobSnapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('MMM d, HH:mm');
    final inventoryData = inventory;
    return Material(
      color: scheme.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 14,
                spacing: 18,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enterprise console for secure content coverage, operations, and audit visibility.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Desktop-first navigation keeps Overview, Coverage, Operations, and Activity distinct so urgent security signals remain easy to scan while critical admin actions stay intact.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      const _HeaderBadge(
                        icon: Icons.security_rounded,
                        label: 'Production environment',
                      ),
                      _HeaderBadge(
                        icon: Icons.schedule_rounded,
                        label:
                            inventoryData == null
                                ? 'Last scan pending'
                                : 'Last scan ${formatter.format(inventoryData.scannedAtUtc.toLocal())}',
                      ),
                      _HeaderBadge(
                        icon:
                            jobSnapshot.isRunning
                                ? Icons.sync_rounded
                                : Icons.verified_rounded,
                        label:
                            jobSnapshot.isRunning
                                ? 'Batch active ${jobSnapshot.settledFiles}/${jobSnapshot.totalFiles}'
                                : 'No active batch',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _DashboardTabBar extends StatelessWidget {
  const _DashboardTabBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: scheme.onPrimaryContainer,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.outlineVariant),
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 18),
              tabs: const [
                Tab(key: adminDashboardHomeTabKey, text: 'Overview'),
                Tab(key: adminDashboardCoverageTabKey, text: 'Coverage'),
                Tab(key: adminDashboardOperationsTabKey, text: 'Operations'),
                Tab(key: adminDashboardActivityTabKey, text: 'Activity'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewHealthPanel extends StatelessWidget {
  const _OverviewHealthPanel({
    required this.snapshot,
    required this.jobSnapshot,
  });

  final _SecureContentDashboardSnapshot snapshot;
  final SecureContentEncryptionJobSnapshot jobSnapshot;

  @override
  Widget build(BuildContext context) {
    final inventory = snapshot.inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${inventory.encryptedCoveragePercent}%',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                inventory.plainFiles == 0
                    ? 'All supported assets currently detected in the secure content root are encrypted at rest.'
                    : '${inventory.plainFiles} supported file${inventory.plainFiles == 1 ? '' : 's'} remain plain and should be remediated from Operations.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricTile(
              label: 'Total detected',
              value: '${inventory.supportedFiles}',
            ),
            _MetricTile(
              label: 'Encrypted',
              value: '${inventory.encryptedFiles}',
            ),
            _MetricTile(
              label: 'Plain remaining',
              value: '${inventory.plainFiles}',
            ),
            _MetricTile(
              label: 'Protected storage',
              value: _humanizeBytes(inventory.totalEncryptedBytes),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InventoryHealthRow(
          label: 'JSON objects',
          encryptedCount: inventory.encryptedJsonFiles,
          plainCount: inventory.plainJsonFiles,
          progressValue: _progressValue(
            inventory.encryptedJsonFiles,
            inventory.encryptedJsonFiles + inventory.plainJsonFiles,
          ),
          icon: Icons.data_object_rounded,
        ),
        const SizedBox(height: 12),
        _InventoryHealthRow(
          label: 'Images',
          encryptedCount: inventory.encryptedImageFiles,
          plainCount: inventory.plainImageFiles,
          progressValue: _progressValue(
            inventory.encryptedImageFiles,
            inventory.encryptedImageFiles + inventory.plainImageFiles,
          ),
          icon: Icons.image_outlined,
        ),
        const SizedBox(height: 12),
        _InventoryHealthRow(
          label: 'Video',
          encryptedCount: inventory.encryptedVideoFiles,
          plainCount: inventory.plainVideoFiles,
          progressValue: _progressValue(
            inventory.encryptedVideoFiles,
            inventory.encryptedVideoFiles + inventory.plainVideoFiles,
          ),
          icon: Icons.video_library_outlined,
        ),
        const SizedBox(height: 14),
        _StatusPill(
          label:
              jobSnapshot.isRunning
                  ? 'Active batch ${jobSnapshot.settledFiles}/${jobSnapshot.totalFiles}'
                  : 'Inventory stable',
          tone:
              jobSnapshot.failedFiles > 0
                  ? _AlertTone.error
                  : inventory.plainFiles > 0
                  ? _AlertTone.warning
                  : _AlertTone.success,
        ),
      ],
    );
  }

  static double _progressValue(int encryptedCount, int totalCount) {
    if (totalCount <= 0) {
      return 0;
    }
    return encryptedCount / totalCount;
  }
}

class _InventoryHealthRow extends StatelessWidget {
  const _InventoryHealthRow({
    required this.label,
    required this.encryptedCount,
    required this.plainCount,
    required this.progressValue,
    required this.icon,
  });

  final String label;
  final int encryptedCount;
  final int plainCount;
  final double progressValue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Text(
              '$encryptedCount encrypted / $plainCount plain',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progressValue, minHeight: 8),
      ],
    );
  }
}

class _OverviewActionPanel extends StatelessWidget {
  const _OverviewActionPanel({
    required this.isRefreshing,
    required this.isWarmingCaches,
    required this.isEncrypting,
    required this.onRefresh,
    required this.onWarmCaches,
    required this.onOpenCoverage,
    required this.onOpenOperations,
    required this.onOpenSync,
  });

  final bool isRefreshing;
  final bool isWarmingCaches;
  final bool isEncrypting;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onWarmCaches;
  final VoidCallback onOpenCoverage;
  final VoidCallback onOpenOperations;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: isRefreshing ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(isRefreshing ? 'Running scan...' : 'Run scan'),
        ),
        OutlinedButton.icon(
          onPressed: isWarmingCaches || isEncrypting ? null : onWarmCaches,
          icon: const Icon(Icons.bolt_rounded),
          label: Text(isWarmingCaches ? 'Warming cache...' : 'Warm cache'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenCoverage,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('Open coverage'),
        ),
        OutlinedButton.icon(
          onPressed: onOpenOperations,
          icon: const Icon(Icons.settings_input_component_rounded),
          label: const Text('Open operations'),
        ),
        TextButton.icon(
          onPressed: onOpenSync,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Open sync tools'),
        ),
      ],
    );
  }
}

class _CoverageToolbar extends StatelessWidget {
  const _CoverageToolbar({
    required this.query,
    required this.statusFilter,
    required this.kindFilter,
    required this.onQueryChanged,
    required this.onStatusFilterChanged,
    required this.onKindFilterChanged,
  });

  final String query;
  final String statusFilter;
  final SecureContentKind? kindFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<SecureContentKind?> onKindFilterChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Content coverage',
      subtitle:
          'Search and filter the local inventory by asset name, content type, and encryption status before opening Operations.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 340,
            child: TextFormField(
              initialValue: query,
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                labelText: 'Search inventory',
                hintText: 'Filename, type, or status',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All status')),
                DropdownMenuItem(value: 'encrypted', child: Text('Encrypted')),
                DropdownMenuItem(value: 'plain', child: Text('Plain')),
                DropdownMenuItem(
                  value: 'warning',
                  child: Text('Needs attention'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onStatusFilterChanged(value);
                }
              },
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<SecureContentKind?>(
              value: kindFilter,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem<SecureContentKind?>(
                  value: null,
                  child: Text('All types'),
                ),
                DropdownMenuItem<SecureContentKind?>(
                  value: SecureContentKind.json,
                  child: Text('JSON'),
                ),
                DropdownMenuItem<SecureContentKind?>(
                  value: SecureContentKind.image,
                  child: Text('Image'),
                ),
                DropdownMenuItem<SecureContentKind?>(
                  value: SecureContentKind.video,
                  child: Text('Video'),
                ),
              ],
              onChanged: onKindFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverageSummaryGrid extends StatelessWidget {
  const _CoverageSummaryGrid({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final inventory = snapshot.inventory;
    final cards = <_OverviewMetricData>[
      _OverviewMetricData(
        label: 'Total assets',
        value: '${inventory.supportedFiles}',
        supportingText: 'Supported secure content assets detected',
        icon: Icons.folder_copy_outlined,
      ),
      _OverviewMetricData(
        label: 'Secured',
        value: '${inventory.encryptedCoveragePercent}%',
        supportingText: 'Coverage across supported JSON, image, and video',
        icon: Icons.lock_outline_rounded,
      ),
      _OverviewMetricData(
        label: 'Plain warning',
        value: '${inventory.plainFiles}',
        supportingText: 'Assets still readable without encryption at rest',
        icon: Icons.warning_amber_rounded,
      ),
      _OverviewMetricData(
        label: 'Protected bytes',
        value: _humanizeBytes(inventory.totalEncryptedBytes),
        supportingText: 'Encrypted footprint currently available offline',
        icon: Icons.storage_rounded,
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
            for (final card in cards)
              SizedBox(
                width: tileWidth,
                child: _OverviewMetricCard(metric: card),
              ),
          ],
        );
      },
    );
  }
}

class _CoverageInventoryTable extends StatelessWidget {
  const _CoverageInventoryTable({
    required this.items,
    required this.totalItemCount,
    required this.totalInventoryCount,
    required this.onOpenOperations,
  });

  final List<SecureContentInventoryItem> items;
  final int totalItemCount;
  final int totalInventoryCount;
  final VoidCallback onOpenOperations;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    if (items.isEmpty) {
      return Text(
        totalInventoryCount == 0
            ? 'No supported JSON, image, or video files were detected in the secure content root.'
            : 'No inventory rows match the current filters.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Showing ${items.length} of $totalItemCount matching assets.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Asset')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('Modified')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          item.relativePath,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_contentKindLabel(item.kind))),
                    DataCell(Text(_humanizeBytes(item.sizeBytes))),
                    DataCell(
                      Text(formatter.format(item.modifiedAtUtc.toLocal())),
                    ),
                    DataCell(
                      _StatusPill(
                        label: item.isEncrypted ? 'Encrypted' : 'Plain',
                        tone:
                            item.isEncrypted
                                ? _AlertTone.success
                                : _AlertTone.warning,
                      ),
                    ),
                    DataCell(
                      item.isEncrypted
                          ? Text(
                            'Protected',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                          : TextButton.icon(
                            onPressed: onOpenOperations,
                            icon: const Icon(Icons.lock_rounded),
                            label: const Text('Open Operations'),
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _AlertTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _AlertTone.success => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      _AlertTone.info => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _AlertTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _AlertTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _OperationalHighlightsPanel extends StatelessWidget {
  const _OperationalHighlightsPanel({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    final lastMaintenance = snapshot.lastMaintenanceActivity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HighlightRow(
          label: 'Current operator',
          value:
              '${snapshot.currentSession.displayName} (@${snapshot.currentSession.username})',
        ),
        const SizedBox(height: 10),
        _HighlightRow(
          label: 'Last scan time',
          value: formatter.format(snapshot.inventory.scannedAtUtc.toLocal()),
        ),
        const SizedBox(height: 10),
        _HighlightRow(
          label: 'Last maintenance action',
          value:
              lastMaintenance == null
                  ? 'No maintenance activity recorded yet'
                  : '${lastMaintenance.summary} • ${formatter.format(lastMaintenance.occurredAtUtc.toLocal())}',
        ),
        const SizedBox(height: 10),
        _HighlightRow(
          label: 'Dominant encrypted category',
          value: snapshot.dominantCategoryLabel,
        ),
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({
    required this.inventory,
    required this.errorMessage,
    required this.jobSnapshot,
  });

  final SecureContentInventory inventory;
  final String? errorMessage;
  final SecureContentEncryptionJobSnapshot jobSnapshot;

  @override
  Widget build(BuildContext context) {
    final alerts = <_DashboardAlertItem>[
      if (errorMessage != null)
        _DashboardAlertItem(
          title: 'Inventory scan error',
          message: errorMessage!,
          tone: _AlertTone.error,
        ),
      if (inventory.plainFiles > 0)
        _DashboardAlertItem(
          title: 'Plain files detected',
          message:
              '${inventory.plainFiles} supported files are still unencrypted and visible in the local inventory.',
          tone: _AlertTone.warning,
        ),
      if (inventory.otherFiles > 0)
        _DashboardAlertItem(
          title: 'Unsupported files present',
          message:
              '${inventory.otherFiles} files were detected outside the supported JSON, image, and video set.',
          tone: _AlertTone.info,
        ),
      if (jobSnapshot.failedFiles > 0)
        _DashboardAlertItem(
          title: 'Encryption batch failures',
          message:
              '${jobSnapshot.failedFiles} files failed in the most recent encryption batch and should be reviewed.',
          tone: _AlertTone.error,
        ),
    ];

    if (alerts.isEmpty) {
      alerts.add(
        const _DashboardAlertItem(
          title: 'No active warnings',
          message:
              'Coverage and runtime indicators are stable. No critical alerts are currently surfaced by the local dashboard.',
          tone: _AlertTone.success,
        ),
      );
    }

    return Column(
      children: [
        for (final alert in alerts) ...[
          _AlertTile(alert: alert),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

enum _AlertTone { success, info, warning, error }

class _DashboardAlertItem {
  const _DashboardAlertItem({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final _AlertTone tone;
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final _DashboardAlertItem alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (alert.tone) {
      _AlertTone.success => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.verified_rounded,
      ),
      _AlertTone.info => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
      _AlertTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.warning_amber_rounded,
      ),
      _AlertTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsBanner extends StatelessWidget {
  const _OperationsBanner({
    required this.snapshot,
    required this.selectedSourceCount,
  });

  final SecureContentEncryptionJobSnapshot snapshot;
  final int selectedSourceCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        snapshot.isRunning
            ? 'Encrypting secure content batch'
            : selectedSourceCount > 0
            ? 'Pending secure content import'
            : 'Operations console is ready';
    final description =
        snapshot.isRunning
            ? (snapshot.statusText ??
                'A protected import batch is currently encrypting selected content.')
            : selectedSourceCount > 0
            ? '$selectedSourceCount selected file${selectedSourceCount == 1 ? '' : 's'} are ready to review and encrypt.'
            : 'Use this tab to prepare sources, monitor active jobs, and run maintenance without mixing workflows.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.10),
            scheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            snapshot.isRunning
                ? Icons.data_usage_rounded
                : Icons.admin_panel_settings_outlined,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: snapshot.percentComplete,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.isRunning
                      ? '${snapshot.settledFiles} of ${snapshot.totalFiles} files settled • ${_humanizeBytes(snapshot.processedBytes)} processed'
                      : selectedSourceCount > 0
                      ? 'Review the queue below, then start an encrypted import.'
                      : 'No active encryption job is running.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsQueuePanel extends StatelessWidget {
  const _OperationsQueuePanel({
    required this.snapshot,
    required this.selectedSourceCount,
  });

  final SecureContentEncryptionJobSnapshot snapshot;
  final int selectedSourceCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(label: 'Active', value: '${snapshot.activeFiles}'),
            _StatChip(label: 'Queued', value: '${snapshot.queuedFiles}'),
            _StatChip(label: 'Completed', value: '${snapshot.completedFiles}'),
            _StatChip(label: 'Failed', value: '${snapshot.failedFiles}'),
            _StatChip(label: 'Selected', value: '$selectedSourceCount'),
          ],
        ),
        const SizedBox(height: 14),
        if (snapshot.items.isEmpty)
          Text(
            selectedSourceCount == 0
                ? 'No active job and no pending selection. Browse files or a folder to build a batch.'
                : 'Selected sources are ready for review in the encryption workspace below.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: [
              for (final item in snapshot.items.take(5)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.basename(item.sourcePath),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: Text(
                        _SelectedSourcesReviewTable._statusLabel(item.stage),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }
}

class _OperationsHealthPanel extends StatelessWidget {
  const _OperationsHealthPanel({
    required this.inventory,
    required this.snapshot,
  });

  final SecureContentInventory? inventory;
  final SecureContentEncryptionJobSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final inventoryData = inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              label: 'Batch progress',
              value: '${(snapshot.percentComplete * 100).round()}%',
            ),
            _StatChip(
              label: 'Processed',
              value: _humanizeBytes(snapshot.processedBytes),
            ),
            _StatChip(label: 'Queued files', value: '${snapshot.queuedFiles}'),
            _StatChip(label: 'Failures', value: '${snapshot.failedFiles}'),
          ],
        ),
        const SizedBox(height: 14),
        if (inventoryData != null) ...[
          Text(
            'Encrypted coverage remains at ${inventoryData.encryptedCoveragePercent}% across ${inventoryData.supportedFiles} supported assets.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: inventoryData.encryptedCoveragePercent / 100,
            minHeight: 8,
          ),
        ] else
          Text(
            'Inventory data is still loading.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}

class _OperationsDangerZone extends StatelessWidget {
  const _OperationsDangerZone({
    required this.isBusy,
    required this.onClearCaches,
    required this.onClearLoginRecords,
  });

  final bool isBusy;
  final Future<void> Function() onClearCaches;
  final Future<void> Function() onClearLoginRecords;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'These controls remove decrypted runtime artifacts or local audit history and should be used deliberately.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: isBusy ? null : onClearCaches,
              icon: const Icon(Icons.cleaning_services_rounded),
              label: const Text('Clear decrypted caches'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onClearLoginRecords,
              icon: const Icon(Icons.history_toggle_off_rounded),
              label: const Text('Clear login records'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityFiltersPanel extends StatelessWidget {
  const _ActivityFiltersPanel({
    required this.daysFilter,
    required this.actorFilter,
    required this.typeFilter,
    required this.actorOptions,
    required this.onDaysFilterChanged,
    required this.onActorFilterChanged,
    required this.onTypeFilterChanged,
  });

  final int? daysFilter;
  final String? actorFilter;
  final AdminActivityType? typeFilter;
  final List<String> actorOptions;
  final ValueChanged<int?> onDaysFilterChanged;
  final ValueChanged<String?> onActorFilterChanged;
  final ValueChanged<AdminActivityType?> onTypeFilterChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Activity filters',
      subtitle:
          'Refine the audit view by time range, operator, and action type before reviewing recent logs.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              value: daysFilter,
              decoration: const InputDecoration(labelText: 'Date range'),
              items: const [
                DropdownMenuItem<int?>(value: null, child: Text('All time')),
                DropdownMenuItem<int?>(value: 1, child: Text('Last 24 hours')),
                DropdownMenuItem<int?>(value: 7, child: Text('Last 7 days')),
                DropdownMenuItem<int?>(value: 30, child: Text('Last 30 days')),
              ],
              onChanged: onDaysFilterChanged,
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              value: actorFilter,
              decoration: const InputDecoration(labelText: 'User'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All users'),
                ),
                for (final actor in actorOptions)
                  DropdownMenuItem<String?>(value: actor, child: Text(actor)),
              ],
              onChanged: onActorFilterChanged,
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<AdminActivityType?>(
              value: typeFilter,
              decoration: const InputDecoration(labelText: 'Action type'),
              items: [
                const DropdownMenuItem<AdminActivityType?>(
                  value: null,
                  child: Text('All actions'),
                ),
                for (final type in AdminActivityType.values)
                  DropdownMenuItem<AdminActivityType?>(
                    value: type,
                    child: Text(_activityTypeLabel(type)),
                  ),
              ],
              onChanged: onTypeFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryGrid extends StatelessWidget {
  const _ActivitySummaryGrid({required this.activities});

  final List<AdminActivityRecord> activities;

  @override
  Widget build(BuildContext context) {
    final failureCount =
        activities
            .where(
              (activity) => activity.type == AdminActivityType.loginFailure,
            )
            .length;
    final encryptionCount =
        activities
            .where(
              (activity) => activity.type == AdminActivityType.encryptionBatch,
            )
            .length;
    final maintenanceCount =
        activities
            .where(
              (activity) =>
                  activity.type == AdminActivityType.inventoryRefresh ||
                  activity.type == AdminActivityType.warmCaches ||
                  activity.type == AdminActivityType.clearCaches,
            )
            .length;
    final cards = <_OverviewMetricData>[
      _OverviewMetricData(
        label: 'Visible events',
        value: '${activities.length}',
        supportingText: 'Current rows after filter application',
        icon: Icons.history_rounded,
      ),
      _OverviewMetricData(
        label: 'Auth failures',
        value: '$failureCount',
        supportingText: 'Failed sign-in attempts in the current window',
        icon: Icons.warning_amber_rounded,
      ),
      _OverviewMetricData(
        label: 'Encryption jobs',
        value: '$encryptionCount',
        supportingText: 'Tracked secure content import batches',
        icon: Icons.lock_rounded,
      ),
      _OverviewMetricData(
        label: 'Maintenance',
        value: '$maintenanceCount',
        supportingText: 'Scans, warm-ups, and cache clears recorded',
        icon: Icons.build_circle_outlined,
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
            for (final card in cards)
              SizedBox(
                width: tileWidth,
                child: _OverviewMetricCard(metric: card),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityTablePanel extends StatelessWidget {
  const _ActivityTablePanel({required this.activities});

  final List<AdminActivityRecord> activities;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    if (activities.isEmpty) {
      return Text(
        'No audit events match the current filters.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Timestamp')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final activity in activities.take(20))
            DataRow(
              cells: [
                DataCell(
                  Text(formatter.format(activity.occurredAtUtc.toLocal())),
                ),
                DataCell(Text(activity.actorUsername ?? 'system')),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      activity.summary,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  _StatusPill(
                    label: _activityStatusLabel(activity),
                    tone: _activityTone(activity),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AuditReadinessPanel extends StatelessWidget {
  const _AuditReadinessPanel({
    required this.snapshot,
    required this.activities,
    required this.inventory,
  });

  final _SecureContentDashboardSnapshot snapshot;
  final List<AdminActivityRecord> activities;
  final SecureContentInventory? inventory;

  @override
  Widget build(BuildContext context) {
    final failureCount =
        activities
            .where(
              (activity) => activity.type == AdminActivityType.loginFailure,
            )
            .length;
    final inventoryData = inventory;
    final readinessLabel =
        failureCount == 0 && (inventoryData?.plainFiles ?? 0) == 0
            ? 'Audit posture is stable.'
            : 'Audit posture needs review.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(readinessLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(label: 'Visible events', value: '${activities.length}'),
            _StatChip(label: 'Auth failures', value: '$failureCount'),
            _StatChip(
              label: 'Coverage',
              value:
                  inventoryData == null
                      ? 'Pending'
                      : '${inventoryData.encryptedCoveragePercent}%',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tracked admins: ${snapshot.users.length}. Imported payload so far: ${_humanizeBytes(snapshot.totalImportedBytes)} across ${snapshot.totalImportedItems} items.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

String _contentKindLabel(SecureContentKind kind) {
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

String _activityTypeLabel(AdminActivityType type) {
  switch (type) {
    case AdminActivityType.loginSuccess:
      return 'Login success';
    case AdminActivityType.loginFailure:
      return 'Login failure';
    case AdminActivityType.logout:
      return 'Logout';
    case AdminActivityType.userCreated:
      return 'User created';
    case AdminActivityType.passwordChanged:
      return 'Password changed';
    case AdminActivityType.profileUpdated:
      return 'Profile updated';
    case AdminActivityType.inventoryRefresh:
      return 'Inventory refresh';
    case AdminActivityType.warmCaches:
      return 'Warm caches';
    case AdminActivityType.clearCaches:
      return 'Clear caches';
    case AdminActivityType.encryptionBatch:
      return 'Encryption batch';
    case AdminActivityType.verificationCodeGenerated:
      return 'Verification QR generated';
    case AdminActivityType.verificationCodeRecordsCleared:
      return 'Verification records cleared';
    case AdminActivityType.loginRecordsCleared:
      return 'Login records cleared';
  }
}

String _activityStatusLabel(AdminActivityRecord activity) {
  switch (activity.type) {
    case AdminActivityType.loginFailure:
      return 'Warning';
    case AdminActivityType.encryptionBatch:
      return 'Encrypted';
    case AdminActivityType.verificationCodeGenerated:
    case AdminActivityType.verificationCodeRecordsCleared:
    case AdminActivityType.inventoryRefresh:
    case AdminActivityType.warmCaches:
    case AdminActivityType.clearCaches:
    case AdminActivityType.loginSuccess:
    case AdminActivityType.logout:
    case AdminActivityType.userCreated:
    case AdminActivityType.passwordChanged:
    case AdminActivityType.profileUpdated:
    case AdminActivityType.loginRecordsCleared:
      return 'Success';
  }
}

_AlertTone _activityTone(AdminActivityRecord activity) {
  switch (activity.type) {
    case AdminActivityType.loginFailure:
      return _AlertTone.warning;
    case AdminActivityType.encryptionBatch:
    case AdminActivityType.verificationCodeGenerated:
    case AdminActivityType.verificationCodeRecordsCleared:
    case AdminActivityType.inventoryRefresh:
    case AdminActivityType.warmCaches:
    case AdminActivityType.clearCaches:
    case AdminActivityType.loginSuccess:
    case AdminActivityType.logout:
    case AdminActivityType.userCreated:
    case AdminActivityType.passwordChanged:
    case AdminActivityType.profileUpdated:
    case AdminActivityType.loginRecordsCleared:
      return _AlertTone.success;
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
        return Icons.qr_code_2_rounded;
      case AdminActivityType.verificationCodeRecordsCleared:
        return Icons.restart_alt_rounded;
      case AdminActivityType.loginRecordsCleared:
        return Icons.history_toggle_off_rounded;
    }
  }
}

class _VerificationOperationsPanel extends StatelessWidget {
  const _VerificationOperationsPanel({
    required this.generatedVerificationQr,
    required this.statusMessage,
    required this.statusIsError,
    required this.isGenerating,
    required this.isClearing,
    required this.activities,
    required this.onGenerate,
    required this.onClearRecords,
  });

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
          (activity) =>
              activity.type == AdminActivityType.verificationCodeGenerated ||
              activity.type == AdminActivityType.verificationCodeRecordsCleared,
        )
        .take(5)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generate a QR approval directly in the admin app. The client app only needs to scan it from Settings.',
          style: Theme.of(context).textTheme.bodyMedium,
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
                  'A full-screen QR is shown immediately after generation so the client app can scan it from Settings without any request-code handoff.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onGenerate,
                      icon: const Icon(Icons.open_in_full_rounded),
                      label: const Text('Regenerate and open QR'),
                    ),
                    Text(
                      'Issued ${DateFormat('MMM d, yyyy HH:mm').format(generatedVerificationQr!.issuedAtUtc.toLocal())}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Valid until ${DateFormat('MMM d, yyyy HH:mm').format(generatedVerificationQr!.expiresAtUtc.toLocal())}',
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
        if (verificationActivities.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Recent verification activity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final activity in verificationActivities)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${DateFormat('MMM d, HH:mm').format(activity.occurredAtUtc.toLocal())} • ${activity.summary}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class _LoginRecordsPanel extends StatelessWidget {
  const _LoginRecordsPanel({required this.activities});

  final List<AdminActivityRecord> activities;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, HH:mm');
    final loginActivities = activities
        .where(
          (activity) =>
              activity.type == AdminActivityType.loginSuccess ||
              activity.type == AdminActivityType.loginFailure ||
              activity.type == AdminActivityType.logout ||
              activity.type == AdminActivityType.loginRecordsCleared,
        )
        .take(10)
        .toList(growable: false);

    if (loginActivities.isEmpty) {
      return Text(
        'No login-focused records have been captured yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Event')),
          DataColumn(label: Text('Category')),
        ],
        rows: [
          for (final activity in loginActivities)
            DataRow(
              cells: [
                DataCell(
                  Text(formatter.format(activity.occurredAtUtc.toLocal())),
                ),
                DataCell(Text(activity.actorUsername ?? 'system')),
                DataCell(Text(activity.summary)),
                DataCell(Text(activity.category)),
              ],
            ),
        ],
      ),
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
          const SizedBox(height: 6),
          Text(
            'Leave Video destination empty to preserve detected Reel and Video category folders from the imported source tree.',
            style: Theme.of(context).textTheme.bodySmall,
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
            hintText: 'optional: reels, highlights, or preserve source tree',
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
              final outputPath = resolveSecureImportRelativeOutputPath(
                relativeOutputPath: source.relativeOutputPath,
                kind: source.kind,
                destinationRoot: destinationRoot,
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

class SecureContentInventoryItem {
  const SecureContentInventoryItem({
    required this.relativePath,
    required this.kind,
    required this.isEncrypted,
    required this.sizeBytes,
    required this.modifiedAtUtc,
  });

  final String relativePath;
  final SecureContentKind kind;
  final bool isEncrypted;
  final int sizeBytes;
  final DateTime modifiedAtUtc;
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
    required this.items,
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
  final List<SecureContentInventoryItem> items;

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
  final items = <SecureContentInventoryItem>[];
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
      if (descriptor.kind != SecureContentKind.other) {
        items.add(
          SecureContentInventoryItem(
            relativePath: relativePath,
            kind: descriptor.kind,
            isEncrypted: descriptor.isEncrypted,
            sizeBytes: fileSizeBytes,
            modifiedAtUtc: modifiedAt,
          ),
        );
      }
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
    items:
        items..sort((left, right) {
          if (left.isEncrypted != right.isEncrypted) {
            return left.isEncrypted ? 1 : -1;
          }
          final modifiedCompare = right.modifiedAtUtc.compareTo(
            left.modifiedAtUtc,
          );
          if (modifiedCompare != 0) {
            return modifiedCompare;
          }
          return left.relativePath.toLowerCase().compareTo(
            right.relativePath.toLowerCase(),
          );
        }),
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
