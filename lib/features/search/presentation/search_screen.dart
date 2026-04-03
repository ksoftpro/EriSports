import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search teams, players, competitions',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const DenseSectionHeader(title: 'Recent Searches'),
          const ListTile(dense: true, title: Text('Manchester City')),
          const ListTile(dense: true, title: Text('Erling Haaland')),
          const ListTile(dense: true, title: Text('Champions League')),
        ],
      ),
    );
  }
}