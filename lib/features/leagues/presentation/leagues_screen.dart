import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:flutter/material.dart';

class LeaguesScreen extends StatelessWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: const [
          DenseSectionHeader(title: 'Competitions'),
          _LeagueTile(name: 'Premier League', country: 'England'),
          _LeagueTile(name: 'Serie A', country: 'Italy'),
          _LeagueTile(name: 'LaLiga', country: 'Spain'),
          _LeagueTile(name: 'Bundesliga', country: 'Germany'),
        ],
      ),
    );
  }
}

class _LeagueTile extends StatelessWidget {
  const _LeagueTile({required this.name, required this.country});

  final String name;
  final String country;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const CircleAvatar(radius: 11),
      title: Text(name, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(country, style: Theme.of(context).textTheme.labelMedium),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}