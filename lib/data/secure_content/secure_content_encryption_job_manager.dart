import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:eri_sports/data/secure_content/daylysport_secure_content_coordinator.dart';
import 'package:eri_sports/data/secure_content/encrypted_file_resolver.dart';
import 'package:eri_sports/data/secure_content/secure_content_crypto.dart';
import 'package:eri_sports/features/media/security/media_crypto.dart';
import 'package:path/path.dart' as p;

enum SecureContentEncryptionItemStage {
  preparing,
  queued,
  encrypting,
  writingOutput,
  completed,
  skipped,
  failed,
}

class SecureContentEncryptionJobItemState {
  const SecureContentEncryptionJobItemState({
    required this.requestId,
    required this.sourcePath,
    required this.relativeOutputPath,
    required this.kind,
    required this.stage,
    required this.processedBytes,
    required this.totalBytes,
    this.destinationPath,
    this.message,
  });

  final String requestId;
  final String sourcePath;
  final String relativeOutputPath;
  final SecureContentKind? kind;
  final SecureContentEncryptionItemStage stage;
  final int processedBytes;
  final int totalBytes;
  final String? destinationPath;
  final String? message;

  String get fileName => p.basename(sourcePath);

  double get percentComplete {
    if (totalBytes <= 0) {
      return isTerminal ? 1 : 0;
    }
    final effectiveProcessed = isTerminal ? totalBytes : processedBytes;
    return effectiveProcessed.clamp(0, totalBytes) / totalBytes;
  }

  bool get isTerminal {
    switch (stage) {
      case SecureContentEncryptionItemStage.completed:
      case SecureContentEncryptionItemStage.skipped:
      case SecureContentEncryptionItemStage.failed:
        return true;
      case SecureContentEncryptionItemStage.preparing:
      case SecureContentEncryptionItemStage.queued:
      case SecureContentEncryptionItemStage.encrypting:
      case SecureContentEncryptionItemStage.writingOutput:
        return false;
    }
  }

  SecureContentEncryptionJobItemState copyWith({
    SecureContentKind? kind,
    bool clearKind = false,
    SecureContentEncryptionItemStage? stage,
    int? processedBytes,
    int? totalBytes,
    String? destinationPath,
    bool clearDestinationPath = false,
    String? message,
    bool clearMessage = false,
  }) {
    return SecureContentEncryptionJobItemState(
      requestId: requestId,
      sourcePath: sourcePath,
      relativeOutputPath: relativeOutputPath,
      kind: clearKind ? null : (kind ?? this.kind),
      stage: stage ?? this.stage,
      processedBytes: processedBytes ?? this.processedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      destinationPath:
          clearDestinationPath ? null : (destinationPath ?? this.destinationPath),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class SecureContentEncryptionJobSnapshot {
  const SecureContentEncryptionJobSnapshot({
    required this.isRunning,
    required this.isFinished,
    required this.totalFiles,
    required this.completedFiles,
    required this.failedFiles,
    required this.skippedFiles,
    required this.activeFiles,
    required this.queuedFiles,
    required this.totalBytes,
    required this.processedBytes,
    required this.items,
    this.statusText,
    this.currentFileName,
    this.result,
  });

  const SecureContentEncryptionJobSnapshot.idle()
    : isRunning = false,
      isFinished = false,
      totalFiles = 0,
      completedFiles = 0,
      failedFiles = 0,
      skippedFiles = 0,
      activeFiles = 0,
      queuedFiles = 0,
      totalBytes = 0,
      processedBytes = 0,
      items = const <SecureContentEncryptionJobItemState>[],
      statusText = null,
      currentFileName = null,
      result = null;

  final bool isRunning;
  final bool isFinished;
  final int totalFiles;
  final int completedFiles;
  final int failedFiles;
  final int skippedFiles;
  final int activeFiles;
  final int queuedFiles;
  final int totalBytes;
  final int processedBytes;
  final List<SecureContentEncryptionJobItemState> items;
  final String? statusText;
  final String? currentFileName;
  final SecureContentEncryptionBatchResult? result;

  int get settledFiles => completedFiles + failedFiles + skippedFiles;

  double get percentComplete {
    if (totalBytes > 0) {
      return processedBytes.clamp(0, totalBytes) / totalBytes;
    }
    if (totalFiles == 0) {
      return 0;
    }
    return settledFiles / totalFiles;
  }
}

class SecureContentEncryptionJobManager {
  SecureContentEncryptionJobManager({
    required this.coordinator,
    int? maxConcurrentWorkers,
  }) : _maxConcurrentWorkers = _resolveMaxConcurrentWorkers(
         maxConcurrentWorkers,
       );

  final DaylysportSecureContentCoordinator coordinator;
  final int _maxConcurrentWorkers;
  final StreamController<SecureContentEncryptionJobSnapshot> _controller =
      StreamController<SecureContentEncryptionJobSnapshot>.broadcast(sync: true);

  SecureContentEncryptionJobSnapshot _snapshot =
      const SecureContentEncryptionJobSnapshot.idle();
  final LinkedHashMap<String, SecureContentEncryptionJobItemState> _itemsById =
      LinkedHashMap<String, SecureContentEncryptionJobItemState>();
  Future<SecureContentEncryptionBatchResult>? _activeJob;

  Stream<SecureContentEncryptionJobSnapshot> get stream => _controller.stream;

  SecureContentEncryptionJobSnapshot get snapshot => _snapshot;

  bool get isRunning => _activeJob != null;

  Future<SecureContentEncryptionBatchResult> startBatch({
    required Iterable<SecureContentEncryptionRequest> requests,
    bool overwrite = true,
  }) {
    if (_activeJob != null) {
      throw StateError('A secure content encryption job is already running.');
    }

    final normalizedRequests = requests
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => SecureContentEncryptionRequest(
            sourcePath: entry.value.sourcePath,
            relativeOutputPath: entry.value.relativeOutputPath,
            requestId: entry.value.requestId ?? 'request-${entry.key}',
          ),
        )
        .toList(growable: false);

    _resetItems(normalizedRequests);
    _publishSnapshot(
      isRunning: true,
      isFinished: false,
      statusText:
          normalizedRequests.isEmpty
              ? 'No files selected for encryption.'
              : 'Preparing ${normalizedRequests.length} files for encryption.',
      result: null,
    );

    final future = _runBatch(
      normalizedRequests: normalizedRequests,
      overwrite: overwrite,
    );
    _activeJob = future;
    future.whenComplete(() {
      if (identical(_activeJob, future)) {
        _activeJob = null;
      }
    });
    return future;
  }

  void dispose() {
    _controller.close();
  }

  Future<SecureContentEncryptionBatchResult> _runBatch({
    required List<SecureContentEncryptionRequest> normalizedRequests,
    required bool overwrite,
  }) async {
    if (normalizedRequests.isEmpty) {
      final result = const SecureContentEncryptionBatchResult(
        requestedCount: 0,
        encryptedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        encryptedJsonCount: 0,
        encryptedImageCount: 0,
        encryptedVideoCount: 0,
        outputPaths: <String>[],
        failures: <SecureContentEncryptionFailure>[],
        manifestPath: null,
      );
      _publishSnapshot(
        isRunning: false,
        isFinished: true,
        statusText: 'No files selected for encryption.',
        result: result,
      );
      return result;
    }

    final rootDirectory =
        await coordinator.daylySportLocator.getOrCreateDaylySportDirectory();
    final failures = <SecureContentEncryptionFailure>[];
    final outputPaths = <String>[];
    final manifestEntries = <SecureContentImportManifestEntry>[];
    final pendingTasks = Queue<_PreparedEncryptionTask>();
    var encryptedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    var encryptedJsonCount = 0;
    var encryptedImageCount = 0;
    var encryptedVideoCount = 0;

    for (final request in normalizedRequests) {
      final requestId = request.requestId!;
      final sourcePath = request.sourcePath.trim();
      if (sourcePath.isEmpty) {
        skippedCount += 1;
        _updateItem(
          requestId,
          stage: SecureContentEncryptionItemStage.skipped,
          message: 'Skipped empty source path.',
          processedBytes: 0,
          totalBytes: 0,
        );
        continue;
      }

      SecureContentDescriptor descriptor;
      try {
        descriptor = coordinator.fileResolver.describePath(sourcePath);
      } catch (error) {
        failedCount += 1;
        failures.add(
          SecureContentEncryptionFailure(
            sourcePath: sourcePath,
            message: '$error',
          ),
        );
        _updateItem(
          requestId,
          stage: SecureContentEncryptionItemStage.failed,
          message: '$error',
        );
        continue;
      }

      if (descriptor.isEncrypted || descriptor.kind == SecureContentKind.other) {
        skippedCount += 1;
        _updateItem(
          requestId,
          kind: descriptor.kind,
          stage: SecureContentEncryptionItemStage.skipped,
          message: 'Skipped unsupported or already encrypted source.',
        );
        continue;
      }

      final normalizedRelativeOutputPath = coordinator
          .normalizeImportRelativeOutputPath(
            request.relativeOutputPath,
            descriptor.logicalFileName,
          );
      final destinationPath = p.join(
        rootDirectory.path,
        coordinator.encryptedRelativePathForImport(
          normalizedRelativeOutputPath,
          descriptor.kind,
        ),
      );

      try {
        final sourceBytes = await File(sourcePath).length();
        pendingTasks.add(
          _PreparedEncryptionTask(
            requestId: requestId,
            sourcePath: sourcePath,
            logicalRelativePath: normalizedRelativeOutputPath,
            destinationPath: destinationPath,
            kind: descriptor.kind,
            sourceBytes: sourceBytes,
            overwrite: overwrite,
            secureContentType: switch (descriptor.kind) {
              SecureContentKind.json => SecureContentType.json,
              SecureContentKind.image => SecureContentType.image,
              SecureContentKind.video => null,
              SecureContentKind.other => null,
            },
            masterKey: descriptor.kind == SecureContentKind.video
                ? coordinator.mediaMasterKey
                : coordinator.secureContentMasterKey,
          ),
        );
        _updateItem(
          requestId,
          kind: descriptor.kind,
          stage: SecureContentEncryptionItemStage.queued,
          processedBytes: 0,
          totalBytes: sourceBytes,
          destinationPath: destinationPath,
          message: 'Queued for encryption.',
        );
      } catch (error) {
        failedCount += 1;
        failures.add(
          SecureContentEncryptionFailure(
            sourcePath: sourcePath,
            message: '$error',
          ),
        );
        _updateItem(
          requestId,
          kind: descriptor.kind,
          stage: SecureContentEncryptionItemStage.failed,
          message: '$error',
        );
      }
    }

    _publishSnapshot(
      isRunning: true,
      isFinished: false,
      statusText: _runningStatusText(),
      result: null,
    );

    if (pendingTasks.isEmpty) {
      final result = SecureContentEncryptionBatchResult(
        requestedCount: normalizedRequests.length,
        encryptedCount: encryptedCount,
        skippedCount: skippedCount,
        failedCount: failedCount,
        encryptedJsonCount: encryptedJsonCount,
        encryptedImageCount: encryptedImageCount,
        encryptedVideoCount: encryptedVideoCount,
        outputPaths: outputPaths,
        failures: failures,
        manifestPath: null,
      );
      _publishSnapshot(
        isRunning: false,
        isFinished: true,
        statusText: _resultStatusText(result),
        result: result,
      );
      return result;
    }

    final completion = Completer<void>();
    var activeWorkers = 0;

    void maybeComplete() {
      if (pendingTasks.isEmpty && activeWorkers == 0 && !completion.isCompleted) {
        completion.complete();
      }
    }

    void scheduleMore() {
      while (activeWorkers < _maxConcurrentWorkers && pendingTasks.isNotEmpty) {
        final task = pendingTasks.removeFirst();
        activeWorkers += 1;
        unawaited(
          _executeTask(task).then((outcome) async {
            switch (outcome.status) {
              case _TaskOutcomeStatus.completed:
                encryptedCount += 1;
                outputPaths.add(task.destinationPath);
                manifestEntries.add(
                  SecureContentImportManifestEntry(
                    sourcePath: task.sourcePath,
                    encryptedPath: task.destinationPath,
                    encryptedRelativePath: p.relative(
                      task.destinationPath,
                      from: rootDirectory.path,
                    ),
                    logicalPath: task.logicalRelativePath,
                    contentKind: task.kind.name,
                    sourceBytes: outcome.sourceBytes,
                    encryptedBytes: outcome.outputBytes,
                    encryptedAtUtc: DateTime.now().toUtc(),
                  ),
                );
                switch (task.kind) {
                  case SecureContentKind.json:
                    encryptedJsonCount += 1;
                  case SecureContentKind.image:
                    encryptedImageCount += 1;
                  case SecureContentKind.video:
                    encryptedVideoCount += 1;
                  case SecureContentKind.other:
                    break;
                }
              case _TaskOutcomeStatus.failed:
                failedCount += 1;
                failures.add(
                  SecureContentEncryptionFailure(
                    sourcePath: task.sourcePath,
                    message: outcome.message ?? 'Encryption failed.',
                  ),
                );
            }
          }).whenComplete(() {
            activeWorkers -= 1;
            _publishSnapshot(
              isRunning: true,
              isFinished: false,
              statusText: _runningStatusText(),
              result: null,
            );
            scheduleMore();
            maybeComplete();
          }),
        );
      }
      maybeComplete();
    }

    scheduleMore();
    await completion.future;

    final manifestPath = await coordinator.writeImportManifest(
      rootDirectory: rootDirectory,
      entries: manifestEntries,
    );
    final result = SecureContentEncryptionBatchResult(
      requestedCount: normalizedRequests.length,
      encryptedCount: encryptedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      encryptedJsonCount: encryptedJsonCount,
      encryptedImageCount: encryptedImageCount,
      encryptedVideoCount: encryptedVideoCount,
      outputPaths: outputPaths,
      failures: failures,
      manifestPath: manifestPath,
    );

    _publishSnapshot(
      isRunning: false,
      isFinished: true,
      statusText: _resultStatusText(result),
      result: result,
    );
    return result;
  }

  Future<_TaskOutcome> _executeTask(_PreparedEncryptionTask task) async {
    final temporaryDestinationPath = '${task.destinationPath}.part';
    final temporaryFile = File(temporaryDestinationPath);
    if (temporaryFile.existsSync()) {
      await temporaryFile.delete();
    }
    await Directory(p.dirname(temporaryDestinationPath)).create(recursive: true);
    _updateItem(
      task.requestId,
      stage: SecureContentEncryptionItemStage.encrypting,
      processedBytes: 0,
      totalBytes: task.sourceBytes,
      destinationPath: task.destinationPath,
      message: 'Encrypting file content.',
    );
    _publishSnapshot(
      isRunning: true,
      isFinished: false,
      statusText: _runningStatusText(),
      result: null,
    );

    try {
      final workerResult = await _runWorker(
        task: task,
        temporaryDestinationPath: temporaryDestinationPath,
      );
      final finalFile = File(task.destinationPath);
      if (await finalFile.exists()) {
        if (!task.overwrite) {
          throw StateError('Destination already exists: ${task.destinationPath}');
        }
        await finalFile.delete();
      }
      await temporaryFile.rename(task.destinationPath);
      _updateItem(
        task.requestId,
        stage: SecureContentEncryptionItemStage.completed,
        processedBytes: task.sourceBytes,
        totalBytes: task.sourceBytes,
        destinationPath: task.destinationPath,
        message: 'Encryption completed.',
      );
      return _TaskOutcome.completed(
        sourceBytes: workerResult.sourceBytes,
        outputBytes: workerResult.outputBytes,
      );
    } catch (error) {
      if (temporaryFile.existsSync()) {
        await temporaryFile.delete();
      }
      _updateItem(
        task.requestId,
        stage: SecureContentEncryptionItemStage.failed,
        processedBytes: task.sourceBytes,
        totalBytes: task.sourceBytes,
        message: '$error',
      );
      return _TaskOutcome.failed('$error');
    }
  }

  Future<_WorkerSuccess> _runWorker({
    required _PreparedEncryptionTask task,
    required String temporaryDestinationPath,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<_WorkerSuccess>();

    late final StreamSubscription<dynamic> receiveSubscription;
    late final StreamSubscription<dynamic> errorSubscription;
    late final StreamSubscription<dynamic> exitSubscription;

    receiveSubscription = receivePort.listen((dynamic message) {
      if (message is! Map<Object?, Object?>) {
        return;
      }

      final type = message['type'] as String?;
      switch (type) {
        case 'progress':
          final stageName = message['stage'] as String? ?? 'encrypting';
          _updateItem(
            task.requestId,
            stage: stageName == 'writingOutput'
                ? SecureContentEncryptionItemStage.writingOutput
                : SecureContentEncryptionItemStage.encrypting,
            processedBytes: (message['processedBytes'] as int?) ?? 0,
            totalBytes: (message['totalBytes'] as int?) ?? task.sourceBytes,
            destinationPath: task.destinationPath,
            message: stageName == 'writingOutput'
                ? 'Writing encrypted output.'
                : 'Encrypting file content.',
          );
          _publishSnapshot(
            isRunning: true,
            isFinished: false,
            statusText: _runningStatusText(),
            result: null,
          );
        case 'complete':
          if (!completer.isCompleted) {
            completer.complete(
              _WorkerSuccess(
                sourceBytes: (message['sourceBytes'] as int?) ?? task.sourceBytes,
                outputBytes: (message['outputBytes'] as int?) ?? 0,
              ),
            );
          }
        case 'error':
          if (!completer.isCompleted) {
            final errorMessage = message['message'] as String? ?? 'Encryption failed.';
            completer.completeError(StateError(errorMessage));
          }
      }
    });

    errorSubscription = errorPort.listen((dynamic message) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Encryption worker crashed for ${task.sourcePath}: $message'),
        );
      }
    });

    exitSubscription = exitPort.listen((dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Encryption worker exited unexpectedly for ${task.sourcePath}.'),
        );
      }
    });

    final isolate = await Isolate.spawn<Map<String, Object?>>(
      _secureContentEncryptionWorkerMain,
      <String, Object?>{
        'sendPort': receivePort.sendPort,
        'sourcePath': task.sourcePath,
        'destinationPath': temporaryDestinationPath,
        'masterKey': Uint8List.fromList(task.masterKey),
        'kind': task.kind.name,
        'contentType': task.secureContentType?.name,
      },
      errorsAreFatal: true,
    );
    isolate.addErrorListener(errorPort.sendPort);
    isolate.addOnExitListener(exitPort.sendPort);

    try {
      return await completer.future;
    } finally {
      await receiveSubscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      receivePort.close();
      errorPort.close();
      exitPort.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  void _resetItems(List<SecureContentEncryptionRequest> requests) {
    _itemsById
      ..clear()
      ..addEntries(
        requests.map(
          (request) => MapEntry(
            request.requestId!,
            SecureContentEncryptionJobItemState(
              requestId: request.requestId!,
              sourcePath: request.sourcePath,
              relativeOutputPath: request.relativeOutputPath,
              kind: null,
              stage: SecureContentEncryptionItemStage.preparing,
              processedBytes: 0,
              totalBytes: 0,
            ),
          ),
        ),
      );
  }

  void _updateItem(
    String requestId, {
    SecureContentKind? kind,
    SecureContentEncryptionItemStage? stage,
    int? processedBytes,
    int? totalBytes,
    String? destinationPath,
    String? message,
  }) {
    final current = _itemsById[requestId];
    if (current == null) {
      return;
    }

    _itemsById[requestId] = current.copyWith(
      kind: kind,
      stage: stage,
      processedBytes: processedBytes,
      totalBytes: totalBytes,
      destinationPath: destinationPath,
      message: message,
    );
  }

  void _publishSnapshot({
    required bool isRunning,
    required bool isFinished,
    required String? statusText,
    required SecureContentEncryptionBatchResult? result,
  }) {
    final items = _itemsById.values.toList(growable: false);
    final completedFiles = items
        .where((item) => item.stage == SecureContentEncryptionItemStage.completed)
        .length;
    final failedFiles = items
        .where((item) => item.stage == SecureContentEncryptionItemStage.failed)
        .length;
    final skippedFiles = items
        .where((item) => item.stage == SecureContentEncryptionItemStage.skipped)
        .length;
    final activeFiles = items
        .where(
          (item) =>
              item.stage == SecureContentEncryptionItemStage.encrypting ||
              item.stage == SecureContentEncryptionItemStage.writingOutput,
        )
        .length;
    final queuedFiles = items
        .where(
          (item) =>
              item.stage == SecureContentEncryptionItemStage.preparing ||
              item.stage == SecureContentEncryptionItemStage.queued,
        )
        .length;
    final totalBytes = items.fold<int>(0, (sum, item) => sum + item.totalBytes);
    final processedBytes = items.fold<int>(0, (sum, item) {
      if (item.totalBytes <= 0) {
        return sum;
      }
      if (item.isTerminal) {
        return sum + item.totalBytes;
      }
      return sum + min(item.processedBytes, item.totalBytes);
    });
    final currentFileName = items
        .where(
          (item) =>
              item.stage == SecureContentEncryptionItemStage.encrypting ||
              item.stage == SecureContentEncryptionItemStage.writingOutput,
        )
        .map((item) => item.fileName)
        .cast<String?>()
        .firstOrNull;

    _snapshot = SecureContentEncryptionJobSnapshot(
      isRunning: isRunning,
      isFinished: isFinished,
      totalFiles: items.length,
      completedFiles: completedFiles,
      failedFiles: failedFiles,
      skippedFiles: skippedFiles,
      activeFiles: activeFiles,
      queuedFiles: queuedFiles,
      totalBytes: totalBytes,
      processedBytes: processedBytes,
      items: items,
      statusText: statusText,
      currentFileName: currentFileName,
      result: result,
    );
    if (!_controller.isClosed) {
      _controller.add(_snapshot);
    }
  }

  String _runningStatusText() {
    final items = _itemsById.values.toList(growable: false);
    final completedFiles = items
      .where((item) => item.stage == SecureContentEncryptionItemStage.completed)
      .length;
    final failedFiles = items
      .where((item) => item.stage == SecureContentEncryptionItemStage.failed)
      .length;
    final skippedFiles = items
      .where((item) => item.stage == SecureContentEncryptionItemStage.skipped)
      .length;
    final activeFiles = items
      .where(
        (item) =>
          item.stage == SecureContentEncryptionItemStage.encrypting ||
          item.stage == SecureContentEncryptionItemStage.writingOutput,
      )
      .length;
    final queuedFiles = items
      .where(
        (item) =>
          item.stage == SecureContentEncryptionItemStage.preparing ||
          item.stage == SecureContentEncryptionItemStage.queued,
      )
      .length;
    final settledFiles = completedFiles + failedFiles + skippedFiles;
    final parts = <String>[
      '$settledFiles of ${items.length} files settled',
      if (activeFiles > 0) '$activeFiles active',
      if (queuedFiles > 0) '$queuedFiles queued',
      if (failedFiles > 0) '$failedFiles failed',
      if (skippedFiles > 0) '$skippedFiles skipped',
    ];
    return parts.join(' • ');
  }

  String _resultStatusText(SecureContentEncryptionBatchResult result) {
    final parts = <String>[
      'Encrypted ${result.encryptedCount} of ${result.requestedCount} files.',
      if (result.skippedCount > 0) 'Skipped ${result.skippedCount}.',
      if (result.failedCount > 0) 'Failed ${result.failedCount}.',
      if (result.manifestPath != null) 'Manifest written.',
    ];
    return parts.join(' ');
  }

  static int _resolveMaxConcurrentWorkers(int? requested) {
    if (requested != null) {
      return requested.clamp(1, 4);
    }
    final available = max(1, Platform.numberOfProcessors - 1);
    return min(2, available);
  }
}

class _PreparedEncryptionTask {
  const _PreparedEncryptionTask({
    required this.requestId,
    required this.sourcePath,
    required this.logicalRelativePath,
    required this.destinationPath,
    required this.kind,
    required this.sourceBytes,
    required this.overwrite,
    required this.masterKey,
    required this.secureContentType,
  });

  final String requestId;
  final String sourcePath;
  final String logicalRelativePath;
  final String destinationPath;
  final SecureContentKind kind;
  final int sourceBytes;
  final bool overwrite;
  final Uint8List masterKey;
  final SecureContentType? secureContentType;
}

enum _TaskOutcomeStatus { completed, failed }

class _TaskOutcome {
  const _TaskOutcome._({
    required this.status,
    required this.sourceBytes,
    required this.outputBytes,
    required this.message,
  });

  const _TaskOutcome.completed({
    required int sourceBytes,
    required int outputBytes,
  }) : this._(
         status: _TaskOutcomeStatus.completed,
         sourceBytes: sourceBytes,
         outputBytes: outputBytes,
         message: null,
       );

  const _TaskOutcome.failed(String message)
    : this._(
        status: _TaskOutcomeStatus.failed,
        sourceBytes: 0,
        outputBytes: 0,
        message: message,
      );

  final _TaskOutcomeStatus status;
  final int sourceBytes;
  final int outputBytes;
  final String? message;
}

class _WorkerSuccess {
  const _WorkerSuccess({
    required this.sourceBytes,
    required this.outputBytes,
  });

  final int sourceBytes;
  final int outputBytes;
}

void _secureContentEncryptionWorkerMain(Map<String, Object?> message) {
  final sendPort = message['sendPort']! as SendPort;
  final sourcePath = message['sourcePath']! as String;
  final destinationPath = message['destinationPath']! as String;
  final masterKey = message['masterKey']! as Uint8List;
  final kindName = message['kind']! as String;
  final contentTypeName = message['contentType'] as String?;

  try {
    switch (kindName) {
      case 'json':
      case 'image':
        final result = encryptSecureFileSync(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          masterKey: masterKey,
          contentType: _secureContentTypeFromName(contentTypeName),
          overwrite: true,
          onProgress: ({
            required int processedBytes,
            required int totalBytes,
            required bool isWritingOutput,
          }) {
            sendPort.send(<String, Object?>{
              'type': 'progress',
              'stage': isWritingOutput ? 'writingOutput' : 'encrypting',
              'processedBytes': processedBytes,
              'totalBytes': totalBytes,
            });
          },
        );
        sendPort.send(<String, Object?>{
          'type': 'complete',
          'sourceBytes': result.sourceBytes,
          'outputBytes': result.outputBytes,
        });
      case 'video':
        final result = encryptMediaFileSync(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          masterKey: masterKey,
          overwrite: true,
          onProgress: ({
            required int processedBytes,
            required int totalBytes,
            required bool isWritingOutput,
          }) {
            sendPort.send(<String, Object?>{
              'type': 'progress',
              'stage': isWritingOutput ? 'writingOutput' : 'encrypting',
              'processedBytes': processedBytes,
              'totalBytes': totalBytes,
            });
          },
        );
        sendPort.send(<String, Object?>{
          'type': 'complete',
          'sourceBytes': result.sourceBytes,
          'outputBytes': result.outputBytes,
        });
      default:
        throw ArgumentError.value(kindName, 'kindName', 'Unsupported content kind');
    }
  } catch (error, stackTrace) {
    sendPort.send(<String, Object?>{
      'type': 'error',
      'message': '$error',
      'stackTrace': '$stackTrace',
    });
  }
}

SecureContentType _secureContentTypeFromName(String? name) {
  switch (name) {
    case 'json':
      return SecureContentType.json;
    case 'image':
      return SecureContentType.image;
  }
  throw ArgumentError.value(name, 'name', 'Unsupported secure content type');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}