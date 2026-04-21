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
const adminCreateUserDisplayNameFieldKey = Key('adminCreateUserDisplayNameField');
const adminCreateUserUsernameFieldKey = Key('adminCreateUserUsernameField');
const adminCreateUserPasswordFieldKey = Key('adminCreateUserPasswordField');
const adminCreateUserConfirmPasswordFieldKey = Key('adminCreateUserConfirmPasswordField');
const adminCreateUserSubmitButtonKey = Key('adminCreateUserSubmitButton');
const adminChangePasswordCurrentFieldKey = Key('adminChangePasswordCurrentField');
const adminChangePasswordNewFieldKey = Key('adminChangePasswordNewField');
const adminChangePasswordConfirmFieldKey = Key('adminChangePasswordConfirmField');
const adminChangePasswordSubmitButtonKey = Key('adminChangePasswordSubmitButton');

typedef SecureContentInventoryScanDelegate = Future<SecureContentInventory> Function(
  String rootPath,
);

SecureContentInventoryScanDelegate secureContentInventoryScanDelegate =
    scanSecureContentInventoryInIsolate;

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
    return ref.read(appServicesProvider).adminActivityService.record(
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

    setState(() {
      _isClearingCaches = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
        await ref.read(appServicesProvider).secureContentCoordinator.clearCaches();
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
      final selectedBytes = _selectedSources.fold<int>(0, (total, source) {
        try {
          return total + File(source.sourcePath).lengthSync();
        } catch (_) {
          return total;
        }
      });
      final selectedKinds = _selectedSources.map((source) => source.kind).toSet();
      final category =
          selectedKinds.length == 1
              ? _kindLabel(selectedKinds.first).toLowerCase()
              : 'mixed';
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
                      decoration: const InputDecoration(labelText: 'Display name'),
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
    final currentUser = authService.users.firstWhere((user) => user.id == session.userId);
    final usernameController = TextEditingController(text: currentUser.username);
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
                      decoration: const InputDecoration(labelText: 'Display name'),
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
    await ref.read(appServicesProvider).adminActivityService.clearLoginRecords(
      actorUserId: session.userId,
      actorUsername: session.username,
    );
    _showStatus('Login records cleared.');
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
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
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
            onRefresh: _refreshInventory,
            onOpenSync: () => context.push('/sync'),
            onLogout: _logout,
          ),
          const SizedBox(height: 18),
          _OverviewMetricsGrid(
            key: adminDashboardOverviewKey,
            snapshot: snapshot,
          ),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                title: 'Status snapshot',
                subtitle:
                    'Track protected file coverage, scan freshness, and overall secure content health at a glance.',
                child: _HomeStatusPanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Operational highlights',
                subtitle:
                    'Surface the current operator, last maintenance event, and the most important runtime signals.',
                child: _OperationalHighlightsPanel(snapshot: snapshot),
              ),
              _SectionCard(
                title: 'Recent critical alerts',
                subtitle:
                    'Highlight open warnings that need attention before the next import, scan, or audit review.',
                child: _AlertsPanel(
                  inventory: snapshot.inventory,
                  errorMessage: _errorMessage,
                  jobSnapshot: _jobSnapshot,
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

        return <Widget>[
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
          const _OperationsBanner(),
          const SizedBox(height: 18),
          _DashboardPanelGrid(
            maxWidth: maxWidth,
            children: [
              _SectionCard(
                title: 'Encryption actions',
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
                              _isPickingSources || _isEncrypting ? null : _pickFiles,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _isPickingSources ? 'Opening picker...' : 'Browse files',
                          ),
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
                              color: _statusIsError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
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
            ],
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
        final children = <Widget>[];
        if (snapshot != null) {
          children.add(
            _DashboardPanelGrid(
              maxWidth: maxWidth,
              children: [
                _SectionCard(
                  key: adminDashboardUserActivityKey,
                  title: 'User activity',
                  subtitle:
                      'Local admin activity, import volume, and recent sign-in behavior.',
                  child: _UserActivityPanel(snapshot: snapshot),
                ),
                _SectionCard(
                  key: adminDashboardRecentActivityKey,
                  title: 'Recent activity',
                  subtitle:
                      'Audit history for authentication, inventory, maintenance, and encryption jobs.',
                  child: _RecentActivityPanel(activities: activities),
                ),
                _SectionCard(
                  title: 'Login records',
                  subtitle:
                      'Authentication-focused activity stream for recent sign-ins, failures, and session changes.',
                  child: _LoginRecordsPanel(activities: activities),
                ),
                if (inventory != null) ...[
                  _InventoryOverviewCard(inventory: inventory),
                  _InventoryBreakdownCard(inventory: inventory),
                  _InventorySamplesCard(inventory: inventory),
                ],
              ],
            ),
          );
        } else if (_isRefreshing && inventory == null) {
          children.add(const _DashboardLoadingPanel());
        } else if (_errorMessage != null) {
          children.add(_DashboardErrorPanel(message: _errorMessage!));
        }

        if (children.isEmpty) {
          children.add(const _DashboardLoadingPanel());
        }
        return children;
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
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const _DashboardWorkspaceHeader(),
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
    return activities.where((record) => _isSameUtcDay(record.occurredAtUtc, today)).length;
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
    return inventory.encryptedDateBuckets.map((bucket) {
      final actionCount = activities
          .where((record) => _isSameUtcDay(record.occurredAtUtc, bucket.dayUtc))
          .length;
      return _DateDashboardMetric(
        dayUtc: bucket.dayUtc,
        encryptedCount: bucket.encryptedFiles,
        encryptedBytes: bucket.encryptedBytes,
        actionCount: actionCount,
      );
    }).toList(growable: false);
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
          importCount: imports.fold<int>(0, (sum, record) => sum + (record.itemCount ?? 0)),
          importedBytes: imports.fold<int>(0, (sum, record) => sum + (record.totalBytes ?? 0)),
          loginCount: userRecords
              .where((record) => record.type == AdminActivityType.loginSuccess)
              .length,
          lastActiveAtUtc: userRecords.isEmpty
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
      orElse: () => _CategoryDashboardMetric(
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
    return left.year == right.year && left.month == right.month && left.day == right.day;
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
                      label: Text(isRefreshing ? 'Refreshing...' : 'Refresh inventory'),
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
                          : formatter.format(inventoryData.scannedAtUtc.toLocal()),
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
        final columns = width >= 1200 ? 4 : width >= 820 ? 2 : 1;
        const spacing = 14.0;
        final tileWidth =
            columns == 1 ? width : (width - ((columns - 1) * spacing)) / columns;
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
          colors: [
            scheme.surface,
            scheme.surfaceContainerLow,
          ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Text(metric.supportingText, style: Theme.of(context).textTheme.bodySmall),
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
    final columns = maxWidth >= 1360 ? 3 : maxWidth >= 900 ? 2 : 1;
    const spacing = 16.0;
    final itemWidth =
        columns == 1 ? maxWidth : (maxWidth - ((columns - 1) * spacing)) / columns;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final child in children)
          SizedBox(width: itemWidth, child: child),
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
  const _DashboardWorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                          'Professional secure content dashboard for imports, monitoring, and audit review.',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Use the tabs below to move between executive health, coverage analytics, encryption operations, and full activity records without mixing workflows.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _HeaderBadge(
                        icon: Icons.dashboard_customize_rounded,
                        label: 'Dashboard view',
                      ),
                      _HeaderBadge(
                        icon: Icons.lock_outline_rounded,
                        label: 'Encrypted operations',
                      ),
                      _HeaderBadge(
                        icon: Icons.fact_check_outlined,
                        label: 'Audit ready',
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
                Tab(key: adminDashboardHomeTabKey, text: 'Home'),
                Tab(key: adminDashboardCoverageTabKey, text: 'Coverage & Trends'),
                Tab(
                  key: adminDashboardOperationsTabKey,
                  text: 'Encryption & Maintenance',
                ),
                Tab(
                  key: adminDashboardActivityTabKey,
                  text: 'Activity & Records',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeStatusPanel extends StatelessWidget {
  const _HomeStatusPanel({required this.snapshot});

  final _SecureContentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final inventory = snapshot.inventory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricTile(label: 'Total detected', value: '${inventory.supportedFiles}'),
            _MetricTile(label: 'Encrypted', value: '${inventory.encryptedFiles}'),
            _MetricTile(label: 'Plain remaining', value: '${inventory.plainFiles}'),
            _MetricTile(
              label: 'Protected storage',
              value: _humanizeBytes(inventory.totalEncryptedBytes),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          inventory.plainFiles == 0
              ? 'All supported files currently detected by the scanner are encrypted at rest.'
              : '${inventory.plainFiles} supported files still remain in plain form and should be prioritized for the next protected import pass.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
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
          value: '${snapshot.currentSession.displayName} (@${snapshot.currentSession.username})',
        ),
        const SizedBox(height: 10),
        _HighlightRow(
          label: 'Last scan time',
          value: formatter.format(snapshot.inventory.scannedAtUtc.toLocal()),
        ),
        const SizedBox(height: 10),
        _HighlightRow(
          label: 'Last maintenance action',
          value: lastMaintenance == null
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                      ),
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
  const _OperationsBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Icon(Icons.admin_panel_settings_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Primary encryption workflows are separated from maintenance utilities.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use the import workspace for protected file onboarding, and keep cache or cleanup actions in the lower-emphasis maintenance panel. Sensitive operations should always be reviewed before execution.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
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
              Icon(metric.icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label, style: Theme.of(context).textTheme.titleSmall),
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
    final maxCount = metrics.fold<int>(1, (maxValue, item) => math.max(maxValue, item.encryptedCount));
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
              value: metrics.isEmpty ? 'No data' : '${metrics.first.encryptedCount} items',
            ),
            _StatChip(
              label: 'Encrypted size',
              value: _humanizeBytes(snapshot.totalEncryptedBytes),
            ),
            _StatChip(
              label: 'Avg item size',
              value: snapshot.totalEncryptedFiles == 0
                  ? '0 B'
                  : _humanizeBytes(
                    (snapshot.totalEncryptedBytes / snapshot.totalEncryptedFiles).round(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  isWarmingCaches || isClearingCaches || isEncrypting ? null : onWarmCaches,
              icon: const Icon(Icons.bolt_rounded),
              label: Text(isWarmingCaches ? 'Warming caches...' : 'Warm secure caches'),
            ),
            OutlinedButton.icon(
              onPressed:
                  isWarmingCaches || isClearingCaches || isEncrypting ? null : onClearCaches,
              icon: const Icon(Icons.cleaning_services_rounded),
              label: Text(
                isClearingCaches ? 'Clearing caches...' : 'Clear decrypted caches',
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
              _StatChip(label: 'Supported files', value: '${inventoryData.supportedFiles}'),
              _StatChip(label: 'Plain files', value: '${inventoryData.plainFiles}'),
              _StatChip(label: 'Encrypted files', value: '${inventoryData.encryptedFiles}'),
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
                    Text(activity.summary, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(activity.occurredAtUtc.toLocal())} • ${activity.actorUsername ?? 'system'} • ${activity.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((activity.itemCount ?? 0) > 0 || (activity.totalBytes ?? 0) > 0)
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
      case AdminActivityType.loginRecordsCleared:
        return Icons.history_toggle_off_rounded;
    }
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
                DataCell(Text(formatter.format(activity.occurredAtUtc.toLocal()))),
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

      if (descriptor.isEncrypted && descriptor.kind != SecureContentKind.other) {
        final dayUtc = DateTime.utc(modifiedAt.year, modifiedAt.month, modifiedAt.day);
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
