import 'package:flutter/material.dart';

class PendingVerificationPlaceholder extends StatelessWidget {
  const PendingVerificationPlaceholder({
    this.compact = false,
    this.title = 'Pending verification',
    this.message = 'Official approval is required before this content can be viewed.',
    super.key,
  });

  final bool compact;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle =
        compact
            ? Theme.of(context).textTheme.labelMedium
            : Theme.of(context).textTheme.titleMedium;
    final messageStyle =
        compact
            ? Theme.of(context).textTheme.labelSmall
            : Theme.of(context).textTheme.bodyMedium;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerLow,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 24,
            vertical: compact ? 6 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: compact ? 18 : 44,
                color: scheme.primary,
              ),
              SizedBox(height: compact ? 4 : 12),
              Text(
                compact ? 'Pending' : title,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: messageStyle?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PendingVerificationChip extends StatelessWidget {
  const PendingVerificationChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            'Pending verification',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}