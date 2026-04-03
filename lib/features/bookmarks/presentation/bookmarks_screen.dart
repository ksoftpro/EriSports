import 'package:eri_sports/shared/widgets/dense_section_header.dart';
import 'package:flutter/material.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: const [
          DenseSectionHeader(title: 'Favorites'),
          ListTile(
            dense: true,
            leading: Icon(Icons.shield_outlined),
            title: Text('Arsenal'),
            subtitle: Text('Team'),
          ),
          ListTile(
            dense: true,
            leading: Icon(Icons.emoji_events_outlined),
            title: Text('Premier League'),
            subtitle: Text('Competition'),
          ),
        ],
      ),
    );
  }
}