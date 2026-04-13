import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/features/media/data/daylysport_media_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final daylySportMediaRepositoryProvider = Provider<DaylySportMediaRepository>((
  ref,
) {
  final services = ref.read(appServicesProvider);
  return DaylySportMediaRepository(
    daylySportLocator: services.daylySportLocator,
  );
});

final daylySportMediaSnapshotProvider =
    AsyncNotifierProvider<DaylySportMediaSnapshotNotifier, DaylySportMediaSnapshot>(
      DaylySportMediaSnapshotNotifier.new,
    );

class DaylySportMediaSnapshotNotifier
    extends AsyncNotifier<DaylySportMediaSnapshot> {
  @override
  Future<DaylySportMediaSnapshot> build() async {
    final repository = ref.read(daylySportMediaRepositoryProvider);
    return repository.loadSnapshot();
  }

  Future<void> refresh() async {
    final repository = ref.read(daylySportMediaRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repository.loadSnapshot(forceRefresh: true),
    );
  }
}
