# EriSports

EriSports now supports two separate Flutter product builds from one shared codebase.

## Build Strategy

The app is split by separate Dart entry points and a shared runtime variant provider instead of maintaining two diverging git branches.

This keeps shared services, repositories, models, and utilities in one place while separating only the routing and feature surface that differs between builds.

Android package IDs:

- Client: `com.erisports.client`
- Admin: `com.erisports.admin`

## Product Builds

### Client build

- Entry point: `lib/main_client.dart`
- Default entry point: `lib/main.dart`
- Purpose: full end-user app experience
- Includes: matches, news, leagues, reels, video, search, settings, sync tools, and the rest of the client-facing runtime
- Excludes: admin-only secure content encryption workflow

### Admin build

- Entry point: `lib/main_admin.dart`
- Purpose: prepare encrypted files for distribution
- Includes: the secure content encryption workflow only
- Excludes: the normal client navigation shell, sync tooling, bundled sports image assets, and user-facing runtime features

## Shared vs Variant-specific Code

Shared code:

- `lib/app/bootstrap/app_services.dart`
- `lib/data/**`
- `lib/features/**` shared models, repositories, and runtime services
- encryption, cache, and secure-content infrastructure

Variant-specific code:

- `lib/app/config/app_product_variant.dart`
- `lib/app/bootstrap/run_eri_sports_app.dart`
- `lib/main_client.dart`
- `lib/main_admin.dart`
- `lib/app/navigation/router.dart`
- `lib/app/app.dart`

## Run Commands

Client app:

```bash
flutter run --flavor client -t lib/main_client.dart
```

Admin app:

```bash
flutter run --flavor admin -t lib/main_admin.dart
```

The default `flutter run` path still launches the client build through `lib/main.dart`.

## Build Commands

Client build:

```bash
flutter build apk --flavor client --target lib/main_client.dart
```

Admin build:

```bash
flutter build apk --flavor admin --target lib/main_admin.dart
```

## Android Launcher Icons

Flavor-specific launcher icons are generated into Android source sets so each build keeps its own branding.

Regenerate them with:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/generate_android_flavor_icons.ps1
```

The client flavor uses the base icon artwork and the admin flavor adds an `ADMIN` badge on top of that artwork.

## Git Branch Control

Do not maintain separate long-lived product branches for Client and Admin. Both apps ship from the same codebase and the flavor split is the product boundary.

Recommended workflow:

- Keep shared development on `main` and short-lived feature branches.
- Use one release commit for a version that contains both flavors.
- If you need branch-based release control, create release branches from the same tested commit, for example `release/client-v1.0.0` and `release/admin-v1.0.0`.
- Tag the exact build commits after producing APKs so both products can be reproduced later.

## Notes

- The client build no longer exposes the admin secure-content route from Settings.
- The admin build now uses a dedicated minimal bootstrap path and single-screen app so it avoids loading the client router and client service graph.
- Android now uses distinct product flavors, launcher icons, labels, and application IDs so the Admin and Client APKs are separate installable apps.
- The Android package namespace is shared at source level, while each flavor publishes with its own install package ID.
- Flutter assets are flavor-scoped, so sports banners, league art, player images, team badges, and placeholders are bundled only in the client flavor.
