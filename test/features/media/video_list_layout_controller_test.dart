import 'package:eri_sports/app/theme/theme_mode_controller.dart';
import 'package:eri_sports/features/media/presentation/video_list_layout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads stored layout mode and persists updates', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'video_list_layout_mode_v1': 'small',
    });
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(videoListLayoutModeProvider),
      VideoListLayoutMode.smallThumbnails,
    );

    await container
        .read(videoListLayoutModeProvider.notifier)
        .setMode(VideoListLayoutMode.details);

    expect(
      container.read(videoListLayoutModeProvider),
      VideoListLayoutMode.details,
    );
    expect(preferences.getString('video_list_layout_mode_v1'), 'details');
  });
}
