import 'package:eri_sports/app/offline_content/offline_content_controller.dart';
import 'package:flutter/material.dart';

class OfflineContentDeleteProgressScope extends StatelessWidget {
  const OfflineContentDeleteProgressScope({
    required this.child,
    required this.progress,
    super.key,
  });

  final Widget child;
  final OfflineContentDeletionProgress? progress;

  @override
  Widget build(BuildContext context) {
    final currentProgress = progress;
    if (currentProgress == null) {
      return child;
    }

    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.2),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Deleting offline content',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${currentProgress.progressPercent}%',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: currentProgress.progressValue,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentProgress.progressText,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentProgress.detailText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ProgressPill(
                              label: 'Completed',
                              value: '${currentProgress.completedCount}',
                            ),
                            _ProgressPill(
                              label: 'Deleted',
                              value: '${currentProgress.deletedCount}',
                            ),
                            if (currentProgress.missingCount > 0)
                              _ProgressPill(
                                label: 'Missing',
                                value: '${currentProgress.missingCount}',
                              ),
                            if (currentProgress.failedCount > 0)
                              _ProgressPill(
                                label: 'Failed',
                                value: '${currentProgress.failedCount}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
