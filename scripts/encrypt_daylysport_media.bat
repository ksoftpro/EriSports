@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"
set "USAGE_EXIT_CODE=1"
set "INTERACTIVE_MODE=0"

if "%~1"=="" goto :INTERACTIVE_WIZARD
if /I "%~1"=="--help" set "USAGE_EXIT_CODE=0" & goto :USAGE
if /I "%~1"=="-h" set "USAGE_EXIT_CODE=0" & goto :USAGE
if /I "%~1"=="/?" set "USAGE_EXIT_CODE=0" & goto :USAGE
if /I "%~1"=="--generate-key" goto :GENERATE_KEY

if "%~2"=="" goto :USAGE_ERROR

set "INPUT_PATH=%~1"
set "OUTPUT_PATH=%~2"
set "KEY_B64="
set "OVERWRITE_FLAG=--overwrite"

shift
shift

:PARSE_ARGS
if "%~1"=="" goto :AFTER_PARSE

if /I "%~1"=="--overwrite" (
  set "OVERWRITE_FLAG=--overwrite"
  shift
  goto :PARSE_ARGS
)

if /I "%~1"=="--no-overwrite" (
  set "OVERWRITE_FLAG="
  shift
  goto :PARSE_ARGS
)

if /I "%~1"=="--key-b64" (
  if "%~2"=="" (
    echo ERROR: --key-b64 requires a value.
    exit /b 1
  )
  set "KEY_B64=%~2"
  shift
  shift
  goto :PARSE_ARGS
)

if /I "%~1"=="--key-file" (
  if "%~2"=="" (
    echo ERROR: --key-file requires a file path.
    exit /b 1
  )
  if not exist "%~2" (
    echo ERROR: key file not found: %~2
    exit /b 1
  )
  set /p KEY_B64=<"%~2"
  shift
  shift
  goto :PARSE_ARGS
)

if /I "%~1"=="--help" set "USAGE_EXIT_CODE=0" & goto :USAGE
if /I "%~1"=="-h" set "USAGE_EXIT_CODE=0" & goto :USAGE

echo ERROR: unknown option: %~1
goto :USAGE

:AFTER_PARSE
if not defined KEY_B64 set "KEY_B64=%ERI_MEDIA_KEY_B64%"

if not defined KEY_B64 (
  echo ERROR: media key is missing.
  echo Set ERI_MEDIA_KEY_B64 or pass --key-b64 / --key-file.
  echo Tip: run with --generate-key to create a secure key.
  exit /b 1
)

call :CHECK_DART
if errorlevel 1 exit /b 1

call :RUN_PIPELINE
set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%

:INTERACTIVE_WIZARD
set "INTERACTIVE_MODE=1"
set "OVERWRITE_FLAG=--overwrite"

echo.
echo ================================================
echo   EriSports Secure Content Encryption
echo ================================================
echo.

call :CHECK_DART
if errorlevel 1 (
  pause
  exit /b 1
)

:ASK_INPUT
set "INPUT_PATH="
set /p "INPUT_PATH=Step 1/4 - Enter input file or folder path: "
if not defined INPUT_PATH (
  echo Input path cannot be empty.
  goto :ASK_INPUT
)
if not exist "%INPUT_PATH%" (
  echo Input path does not exist: "%INPUT_PATH%"
  goto :ASK_INPUT
)

set "DEFAULT_OUTPUT=%INPUT_PATH%_encrypted"
call :PROMPT_FOR_OUTPUT_DIRECTORY "%DEFAULT_OUTPUT%"
if errorlevel 1 (
  echo Aborted.
  pause
  exit /b 0
)

choice /C YN /M "Step 3/4 - Overwrite existing encrypted files?"
if errorlevel 2 set "OVERWRITE_FLAG="
if errorlevel 1 set "OVERWRITE_FLAG=--overwrite"

set "KEY_B64=%ERI_SECURE_CONTENT_KEY_B64%"
if not defined KEY_B64 set "KEY_B64=%ERI_MEDIA_KEY_B64%"
if not defined KEY_B64 (
  echo.
  echo Step 4/4 - Secure content key is required.
  echo.
  choice /C GMQ /M "Choose: [G]enerate key, [M]anual key entry, [Q]uit"
  if errorlevel 3 (
    echo Aborted.
    pause
    exit /b 0
  )
  if errorlevel 2 goto :MANUAL_KEY
  if errorlevel 1 goto :GENERATE_KEY_AND_USE
)

goto :PREVIEW_AND_CONFIRM

:MANUAL_KEY
set "KEY_B64="
set /p "KEY_B64=Enter ERI_SECURE_CONTENT_KEY_B64 value: "
if not defined KEY_B64 (
  echo Key cannot be empty.
  goto :MANUAL_KEY
)
goto :PREVIEW_AND_CONFIRM

:GENERATE_KEY_AND_USE
call :CREATE_KEY
if errorlevel 1 (
  echo ERROR: failed to generate key.
  pause
  exit /b 1
)
set "KEY_B64=%NEW_KEY%"
echo Generated one-time key for this run.
echo %KEY_B64%
echo.

:PREVIEW_AND_CONFIRM
call :COUNT_SOURCE_FILES "%INPUT_PATH%"

echo.
echo ---------------- Encryption Plan ----------------
echo Repo  : "%REPO_ROOT%"
echo Input : "%INPUT_PATH%"
echo Output: "%OUTPUT_PATH%"
if defined OVERWRITE_FLAG (
  echo Mode  : overwrite enabled
) else (
  echo Mode  : overwrite disabled
)
echo Supported files detected ^(.json,.jpg,.jpeg,.png,.webp,.gif,.bmp,.mp4,.mov,.m4v,.webm,.mkv,.avi,.3gp^): %SOURCE_FILE_COUNT%
echo -----------------------------------------------
echo.

if "%SOURCE_FILE_COUNT%"=="0" (
  echo WARNING: no supported JSON, image, or video files were found in the input path.
  choice /C YN /M "Run encryption anyway?"
  if errorlevel 2 (
    echo Aborted.
    pause
    exit /b 0
  )
) else (
  choice /C YN /M "Start encryption now?"
  if errorlevel 2 (
    echo Aborted.
    pause
    exit /b 0
  )
)

call :RUN_PIPELINE
set "EXIT_CODE=%ERRORLEVEL%"

if "%EXIT_CODE%"=="0" (
  echo.
  echo Finished successfully.
) else (
  echo.
  echo Failed with exit code %EXIT_CODE%.
)

pause
exit /b %EXIT_CODE%

:RUN_PIPELINE
if not exist "%INPUT_PATH%" (
  echo ERROR: input path does not exist: "%INPUT_PATH%"
  exit /b 1
)

call :ENSURE_OUTPUT_DIRECTORY "%OUTPUT_PATH%"
if errorlevel 1 (
  echo ERROR: unable to create or access output directory: "%OUTPUT_PATH%"
  if "%INTERACTIVE_MODE%"=="1" (
    echo Please provide another writable output folder.
    call :PROMPT_FOR_OUTPUT_DIRECTORY "%OUTPUT_PATH%"
    if errorlevel 1 exit /b 1
    call :ENSURE_OUTPUT_DIRECTORY "%OUTPUT_PATH%"
    if errorlevel 1 (
      echo ERROR: output directory is still not writable: "%OUTPUT_PATH%"
      exit /b 1
    )
  ) else (
    echo Tip: run script without arguments to use interactive output-folder prompt.
    exit /b 1
  )
)

if not defined KEY_B64 (
  echo ERROR: secure content key is missing.
  exit /b 1
)

call :COUNT_SOURCE_FILES "%INPUT_PATH%"

pushd "%REPO_ROOT%" >nul 2>&1
if errorlevel 1 (
  echo ERROR: unable to open repo root: "%REPO_ROOT%"
  exit /b 1
)

echo.
echo [encrypt_daylysport_media] Repo  : "%REPO_ROOT%"
echo [encrypt_daylysport_media] Input : "%INPUT_PATH%"
echo [encrypt_daylysport_media] Output: "%OUTPUT_PATH%"
if defined OVERWRITE_FLAG (
  echo [encrypt_daylysport_media] Mode  : overwrite enabled
) else (
  echo [encrypt_daylysport_media] Mode  : overwrite disabled
)
echo [encrypt_daylysport_media] Supported files detected: %SOURCE_FILE_COUNT%
echo.

if defined OVERWRITE_FLAG (
  call dart run tool\encrypt_media.dart --input "%INPUT_PATH%" --output "%OUTPUT_PATH%" --key-base64 "%KEY_B64%" --overwrite
) else (
  call dart run tool\encrypt_media.dart --input "%INPUT_PATH%" --output "%OUTPUT_PATH%" --key-base64 "%KEY_B64%"
)

set "EXIT_CODE=%ERRORLEVEL%"
popd >nul

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Encryption pipeline failed with exit code %EXIT_CODE%.
  exit /b %EXIT_CODE%
)

echo.
echo Encryption pipeline completed successfully.
exit /b 0

:CHECK_DART
where dart >nul 2>&1
if errorlevel 1 (
  echo ERROR: Dart SDK is not available in PATH.
  echo Install Flutter/Dart or open this script from a Flutter-enabled shell.
  exit /b 1
)
exit /b 0

:PROMPT_FOR_OUTPUT_DIRECTORY
set "DEFAULT_OUTPUT=%~1"

:ASK_OUTPUT
set "OUTPUT_PATH="
set /p "OUTPUT_PATH=Step 2/4 - Enter output folder [default: %DEFAULT_OUTPUT%]: "
if not defined OUTPUT_PATH set "OUTPUT_PATH=%DEFAULT_OUTPUT%"

if /I "%OUTPUT_PATH%"=="Q" exit /b 1
if /I "%OUTPUT_PATH%"=="QUIT" exit /b 1

call :ENSURE_OUTPUT_DIRECTORY "%OUTPUT_PATH%"
if errorlevel 1 (
  echo.
  echo Cannot create or access output directory: "%OUTPUT_PATH%"
  echo Enter another writable folder path, or type Q to cancel.
  echo.
  set "DEFAULT_OUTPUT=%OUTPUT_PATH%"
  goto :ASK_OUTPUT
)

exit /b 0

:ENSURE_OUTPUT_DIRECTORY
set "CANDIDATE_OUTPUT=%~1"

if not defined CANDIDATE_OUTPUT exit /b 1

if exist "%CANDIDATE_OUTPUT%" (
  pushd "%CANDIDATE_OUTPUT%" >nul 2>&1
  if errorlevel 1 exit /b 1
  popd >nul
  exit /b 0
)

mkdir "%CANDIDATE_OUTPUT%" >nul 2>&1

if not exist "%CANDIDATE_OUTPUT%" exit /b 1

pushd "%CANDIDATE_OUTPUT%" >nul 2>&1
if errorlevel 1 exit /b 1
popd >nul

exit /b 0

:COUNT_SOURCE_FILES
set "SOURCE_FILE_COUNT=0"
set "COUNT_TARGET=%~1"
for /f "usebackq delims=" %%C in (`powershell -NoProfile -Command "$path=$env:COUNT_TARGET; if(-not (Test-Path -LiteralPath $path)){0; exit}; $exts=@('.json','.jpg','.jpeg','.png','.webp','.gif','.bmp','.mp4','.mov','.m4v','.webm','.mkv','.avi','.3gp'); $encryptedExts=@('.esj','.esi','.esv'); $item=Get-Item -LiteralPath $path; if($item.PSIsContainer){ $files=Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue; ($files.Where({ ($exts -contains $_.Extension.ToLowerInvariant()) -and -not ($encryptedExts -contains $_.Extension.ToLowerInvariant()) })).Count } else { if(($exts -contains $item.Extension.ToLowerInvariant()) -and -not ($encryptedExts -contains $item.Extension.ToLowerInvariant())){1}else{0} }"`) do set "SOURCE_FILE_COUNT=%%C"
if not defined SOURCE_FILE_COUNT set "SOURCE_FILE_COUNT=0"
exit /b 0

:CREATE_KEY
set "NEW_KEY="
for /f "usebackq delims=" %%K in (`powershell -NoProfile -Command "$bytes = New-Object byte[] 32; $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create(); $rng.GetBytes($bytes); $rng.Dispose(); [Convert]::ToBase64String($bytes)"`) do set "NEW_KEY=%%K"
if not defined NEW_KEY exit /b 1
exit /b 0

:GENERATE_KEY
call :CREATE_KEY
if errorlevel 1 (
  echo ERROR: failed to generate key.
  exit /b 1
)

echo Generated ERI_SECURE_CONTENT_KEY_B64 value:
echo %NEW_KEY%
echo.
echo Set it in current shell with:
echo   set ERI_SECURE_CONTENT_KEY_B64=%NEW_KEY%
exit /b 0

:USAGE_ERROR
echo ERROR: missing required arguments.
echo.
goto :USAGE

:USAGE
echo Usage:
echo   scripts\encrypt_daylysport_media.bat ^<input_file_or_folder^> ^<output_folder^> [options]
echo.
echo No arguments:
echo   Launches an interactive click-to-run wizard.
echo.
echo Options:
echo   --overwrite         Overwrite existing encrypted output files (default).
echo   --no-overwrite      Skip overwrite mode.
echo   --key-b64 VALUE     Base64 secure-content key (overrides env var).
echo   --key-file PATH     Read base64 media key from file.
echo   --generate-key      Generate a secure base64 key and print it.
echo   --help              Show this help.
echo.
echo Key source priority:
echo   1) --key-b64
echo   2) --key-file
echo   3) ERI_SECURE_CONTENT_KEY_B64 environment variable
echo   4) ERI_MEDIA_KEY_B64 environment variable
echo.
echo Examples:
echo   scripts\encrypt_daylysport_media.bat "D:\media\raw" "D:\media\encrypted"
echo   scripts\encrypt_daylysport_media.bat "D:\media\raw" "D:\media\encrypted" --no-overwrite
echo   scripts\encrypt_daylysport_media.bat "D:\media\raw" "D:\media\encrypted" --key-file "D:\keys\eri_media_key.txt"
exit /b %USAGE_EXIT_CODE%
