import 'package:eri_sports/app/theme/color_tokens.dart';
import 'package:flutter/material.dart';

class DenseSectionHeader extends StatelessWidget {
  const DenseSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColorTokens.accent,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}