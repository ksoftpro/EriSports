import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // App Title Card
          Card(
            color: scheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EriSports',
                    style: textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your gateway to Eritrean sports scores, stats, and more.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Developer Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _AboutInfoRow(label: 'Developer', value: 'Sharpeth'),
                  _AboutInfoDivider(),
                  _AboutInfoRow(label: 'Gmail', value: 'sharpeth@gmail.com'),
                  _AboutInfoDivider(),
                  _AboutInfoRow(label: 'Telephone', value: '+2917606100'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Business Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _AboutInfoRow(
                    label: 'Incorporation',
                    value: 'Golden Movies Store Distribution',
                  ),
                  _AboutInfoDivider(),
                  _AboutInfoRow(
                    label: 'Business Email',
                    value: 'goldenMovies@gmail.com',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // FAQ Section
          _FaqSection(),
        ],
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutInfoDivider extends StatelessWidget {
  const _AboutInfoDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(height: 1, color: scheme.outline.withValues(alpha: 0.18));
  }
}

class _FaqSection extends StatefulWidget {
  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  final List<bool> _expanded = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAQ',
              style: textTheme.titleLarge?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 8),
            ExpansionPanelList(
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback:
                  (i, isOpen) => setState(() => _expanded[i] = !isOpen),
              children: [
                ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: _expanded[0],
                  headerBuilder:
                      (context, isOpen) => ListTile(
                        title: Text(
                          'How do I change the app theme?',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                  body: ListTile(
                    title: Text(
                      'Go to Settings > Appearance and select System, Light, or Dark mode. The app will instantly update.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
                ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: _expanded[1],
                  headerBuilder:
                      (context, isOpen) => ListTile(
                        title: Text(
                          'How do I update data or sync?',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                  body: ListTile(
                    title: Text(
                      'Use the Synchronize Data button in Settings to refresh all scores, teams, and players from the latest offline files.',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
                ExpansionPanel(
                  canTapOnHeader: true,
                  isExpanded: _expanded[2],
                  headerBuilder:
                      (context, isOpen) => ListTile(
                        title: Text(
                          'Who do I contact for support?',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                  body: ListTile(
                    title: Text(
                      'For any issues, email sharpeth@gmail.com or goldenMovies@gmail.com. We are happy to help!',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
