import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _videoLayoutPrefKey = 'video_list_layout_mode_v1';

enum VideoListLayoutMode {
  details,
  tiles,
  largeThumbnails,
  mediumThumbnails,
  smallThumbnails,
}

extension VideoListLayoutModeX on VideoListLayoutMode {
  String get storageValue {
    switch (this) {
      case VideoListLayoutMode.details:
        return 'details';
      case VideoListLayoutMode.tiles:
        return 'tiles';
      case VideoListLayoutMode.largeThumbnails:
        return 'large';
      case VideoListLayoutMode.mediumThumbnails:
        return 'medium';
      case VideoListLayoutMode.smallThumbnails:
        return 'small';
    }
  }

  String get label {
    switch (this) {
      case VideoListLayoutMode.details:
        return 'Details';
      case VideoListLayoutMode.tiles:
        return 'Tiles';
      case VideoListLayoutMode.largeThumbnails:
        return 'Large';
      case VideoListLayoutMode.mediumThumbnails:
        return 'Medium';
      case VideoListLayoutMode.smallThumbnails:
        return 'Small';
    }
  }

  IconData get icon {
    switch (this) {
      case VideoListLayoutMode.details:
        return Icons.view_agenda_rounded;
      case VideoListLayoutMode.tiles:
        return Icons.grid_view_rounded;
      case VideoListLayoutMode.largeThumbnails:
        return Icons.view_carousel_rounded;
      case VideoListLayoutMode.mediumThumbnails:
        return Icons.view_module_rounded;
      case VideoListLayoutMode.smallThumbnails:
        return Icons.view_list_rounded;
    }
  }

  static VideoListLayoutMode fromStored(String? value) {
    for (final mode in VideoListLayoutMode.values) {
      if (mode.storageValue == value) {
        return mode;
      }
    }
    return VideoListLayoutMode.mediumThumbnails;
  }
}

class VideoListLayoutController extends Notifier<VideoListLayoutMode> {
  @override
  VideoListLayoutMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return VideoListLayoutModeX.fromStored(
      prefs.getString(_videoLayoutPrefKey),
    );
  }

  Future<void> setMode(VideoListLayoutMode mode) async {
    if (state == mode) {
      return;
    }
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_videoLayoutPrefKey, mode.storageValue);
  }
}

final videoListLayoutModeProvider =
    NotifierProvider<VideoListLayoutController, VideoListLayoutMode>(
      VideoListLayoutController.new,
    );
