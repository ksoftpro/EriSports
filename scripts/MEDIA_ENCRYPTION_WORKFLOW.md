# DaylySport Media Encryption Workflow

This project supports encrypting local video media before copying into `daylySport` folders.

## 1) Configure key

Set the same base64 key for:
- laptop encryption script
- app runtime build (`--dart-define=ERI_MEDIA_KEY_B64=...`)

PowerShell example:

```powershell
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$env:ERI_MEDIA_KEY_B64 = [Convert]::ToBase64String($bytes)
```

## 2) Encrypt batch on laptop

```bat
scripts\encrypt_daylysport_media.bat "D:\raw_media" "D:\encrypted_media"
```

This runs `tool/encrypt_media.dart` and produces:
- encrypted files with `.esv` suffix (example: `goal.mp4.esv`)
- `media_encryption_manifest.json`

## 3) Copy encrypted output to daylySport

Copy encrypted files into desired daylySport folders, for example:
- `daylySport\reels\`
- `daylySport\highlights\`
- `daylySport\updates\`
- `daylySport\news\`

## 4) App runtime behavior

- app detects `.esv` media files as protected videos
- on first playback, it decrypts once into app temp cache
- on later playback, it reuses cached decrypted file
- if encrypted source file changes (size/mtime), cache key changes and stale cache is evicted

## Format

- Encryption: AES-CTR
- Integrity: HMAC-SHA256
- File extension: `.esv`
