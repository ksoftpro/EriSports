# DaylySport Secure Content Workflow

This project supports encrypting local JSON, image, and video content before copying into `daylySport` folders.

## 1) Configure key

Set the same base64 key for:
- laptop encryption script
- app runtime build (`--dart-define=ERI_SECURE_CONTENT_KEY_B64=...` or `--dart-define=ERI_MEDIA_KEY_B64=...`)

PowerShell example:

```powershell
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:ERI_SECURE_CONTENT_KEY_B64 = [Convert]::ToBase64String($bytes)
```

## 2) Encrypt batch on laptop

```bat
scripts\encrypt_daylysport_media.bat "D:\raw_media" "D:\encrypted_media"
```

This runs `tool/encrypt_media.dart` and produces:
- encrypted JSON files with `.esj` suffix (example: `fixtures.json.esj`)
- encrypted image files with `.esi` suffix (example: `headline.png.esi`)
- encrypted video files with `.esv` suffix (example: `goal.mp4.esv`)
- `secure_content_manifest.json`

## 3) Copy encrypted output to daylySport

Copy encrypted files into desired daylySport folders, for example:
- `daylySport\json\`
- `daylySport\reels\`
- `daylySport\highlights\`
- `daylySport\updates\`
- `daylySport\news\`

## 4) App runtime behavior

- app detects `.json.esj` files as encrypted JSON and decrypts them into a persistent temp cache keyed by source path, size, and mtime
- app detects `.esi` files as encrypted images and decrypts them into a persistent temp cache for repeat viewing
- app detects `.esv` files as protected videos and decrypts once into temp cache for repeat playback
- if encrypted source file changes (size/mtime), cache key changes and stale cache is evicted

## Format

- Encryption: AES-CTR
- Integrity: HMAC-SHA256
- JSON extension: `.esj`
- Image extension: `.esi`
- Video extension: `.esv`
