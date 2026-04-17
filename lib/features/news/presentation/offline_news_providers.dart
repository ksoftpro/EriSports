import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/app/sync/daylysport_sync_controller.dart';
import 'package:eri_sports/features/news/data/offline_news_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final offlineNewsRepositoryProvider = Provider<OfflineNewsRepository>((ref) {
  final services = ref.read(appServicesProvider);
  return OfflineNewsRepository(daylySportLocator: services.daylySportLocator);
});

final offlineNewsGalleryProvider = AsyncNotifierProvider<
  OfflineNewsGalleryNotifier,
  OfflineNewsGallerySnapshot
>(OfflineNewsGalleryNotifier.new);

class OfflineNewsGalleryNotifier
    extends AsyncNotifier<OfflineNewsGallerySnapshot> {
  @override
  Future<OfflineNewsGallerySnapshot> build() async {
    ref.watch(dataRefreshTokenProvider);
    final repository = ref.read(offlineNewsRepositoryProvider);
    return repository.loadGallery();
  }

  Future<void> refreshGallery() async {
    final repository = ref.read(offlineNewsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repository.loadGallery(forceRefresh: true),
    );
  }
}
