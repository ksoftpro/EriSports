import 'package:eri_sports/app/bootstrap/app_services.dart';
import 'package:eri_sports/data/assets/local_asset_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assetResolverProvider = Provider<LocalAssetResolver>((ref) {
  return ref.read(appServicesProvider).assetResolver;
});
