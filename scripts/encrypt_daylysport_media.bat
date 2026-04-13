@echo off
setlocal

if "%~1"=="" (
  echo Usage: scripts\encrypt_daylysport_media.bat ^<input_file_or_folder^> ^<output_folder^>
  echo Example: scripts\encrypt_daylysport_media.bat "D:\media\raw" "D:\media\encrypted"
  exit /b 1
)

if "%~2"=="" (
  echo Missing output folder argument.
  echo Usage: scripts\encrypt_daylysport_media.bat ^<input_file_or_folder^> ^<output_folder^>
  exit /b 1
)

if "%ERI_MEDIA_KEY_B64%"=="" (
  echo Environment variable ERI_MEDIA_KEY_B64 is not set.
  echo Set it once per shell, then rerun this script.
  echo Example:
  echo   set ERI_MEDIA_KEY_B64=YOUR_BASE64_KEY
  exit /b 1
)

set INPUT_PATH=%~1
set OUTPUT_PATH=%~2

echo Encrypting media from "%INPUT_PATH%" to "%OUTPUT_PATH%"...
call dart run tool\encrypt_media.dart --input "%INPUT_PATH%" --output "%OUTPUT_PATH%" --key-base64 "%ERI_MEDIA_KEY_B64%" --overwrite
if errorlevel 1 (
  echo Encryption pipeline failed.
  exit /b 1
)

echo Encryption pipeline completed successfully.
exit /b 0
