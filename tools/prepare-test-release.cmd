@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "STEP=argument validation"
if "%~2"=="" goto :Usage
if not "%~3"=="" goto :Usage
set "NEW_TAG=%~1"
set "PREVIOUS_TAG=%~2"
call :ValidateTag "%NEW_TAG%"
if errorlevel 1 (set "FAIL_REASON=Invalid NEW_TAG."& set "FAIL_CODE=10"& goto :Fail)
call :ValidateTag "%PREVIOUS_TAG%"
if errorlevel 1 (set "FAIL_REASON=Invalid PREVIOUS_TAG."& set "FAIL_CODE=11"& goto :Fail)
if /i "%NEW_TAG%"=="%PREVIOUS_TAG%" (set "FAIL_REASON=NEW_TAG and PREVIOUS_TAG must differ."& set "FAIL_CODE=12"& goto :Fail)

set "BASE=C:\AmongUsMod"
set "SOURCE_REPO=%BASE%\SnowRoles"
set "SOURCE_DLL=%SOURCE_REPO%\bin\Release\net6.0\SnowRoles.dll"
set "DEPLOYED_DLL=C:\Program Files (x86)\Steam\steamapps\common\Among Us\BepInEx\plugins\SnowRoles.dll"
set "ARTIFACTS=%BASE%\release-artifacts"
set "WORK_ROOT=%BASE%\release-work"
set "INPUT_ROOT=%BASE%\release-input"
set "WORK=%WORK_ROOT%\%NEW_TAG%"
set "STAGING=%WORK%\staging"
set "README_INPUT=%INPUT_ROOT%\%NEW_TAG%\README.txt"
set "FINAL_ZIP_NAME=SnowRoles-%NEW_TAG%-Steam.zip"
set "FINAL_ZIP=%ARTIFACTS%\%FINAL_ZIP_NAME%"
set "PREVIOUS_ZIP_NAME=SnowRoles-%PREVIOUS_TAG%-Steam.zip"
set "PREVIOUS_LOCAL=%ARTIFACTS%\%PREVIOUS_ZIP_NAME%"
set "PREVIOUS_DOWNLOAD=%WORK%\%PREVIOUS_ZIP_NAME%"
set "API_JSON=%WORK%\previous-release.json"
set "NEW_SUMS=%WORK%\SHA256SUMS.new.txt"
set "ZIP_LIST=%WORK%\final-zip-list.txt"
set "SUMMARY=%WORK%\RELEASE_SUMMARY.txt"

set "STEP=source repository checks"
git -C "%SOURCE_REPO%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (set "FAIL_REASON=Source repository is not a Git work tree."& set "FAIL_CODE=20"& goto :Fail)
for /f "delims=" %%S in ('git -C "%SOURCE_REPO%" status --porcelain') do set "SOURCE_DIRTY=1"
if defined SOURCE_DIRTY (set "FAIL_REASON=Source repository is not clean."& set "FAIL_CODE=21"& goto :Fail)
for /f "delims=" %%H in ('git -C "%SOURCE_REPO%" rev-parse HEAD') do set "SOURCE_COMMIT=%%H"
if not defined SOURCE_COMMIT (set "FAIL_REASON=Could not read source HEAD."& set "FAIL_CODE=22"& goto :Fail)

set "STEP=DLL identity checks"
if not exist "%SOURCE_DLL%" (set "FAIL_REASON=Source Release DLL does not exist."& set "FAIL_CODE=30"& goto :Fail)
if not exist "%DEPLOYED_DLL%" (set "FAIL_REASON=Deployed DLL does not exist at the fixed path."& set "FAIL_CODE=31"& goto :Fail)
for %%F in ("%SOURCE_DLL%") do set "SOURCE_DLL_SIZE=%%~zF"
for %%F in ("%DEPLOYED_DLL%") do set "DEPLOYED_DLL_SIZE=%%~zF"
call :GetHash "%SOURCE_DLL%" SOURCE_DLL_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash Source Release DLL."& set "FAIL_CODE=32"& goto :Fail)
call :GetHash "%DEPLOYED_DLL%" DEPLOYED_DLL_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash deployed DLL."& set "FAIL_CODE=33"& goto :Fail)
if not "%SOURCE_DLL_SIZE%"=="%DEPLOYED_DLL_SIZE%" (set "FAIL_REASON=Source and deployed DLL sizes differ."& set "FAIL_CODE=34"& goto :Fail)
if /i not "%SOURCE_DLL_HASH%"=="%DEPLOYED_DLL_HASH%" (set "FAIL_REASON=Source and deployed DLL hashes differ."& set "FAIL_CODE=35"& goto :Fail)

set "STEP=README input checks"
if not exist "%README_INPUT%" (set "FAIL_REASON=Release README input does not exist."& set "FAIL_CODE=40"& goto :Fail)
findstr /l /c:"%NEW_TAG%" "%README_INPUT%" >nul
if errorlevel 1 (set "FAIL_REASON=README does not contain NEW_TAG."& set "FAIL_CODE=41"& goto :Fail)
findstr /l /c:"%PREVIOUS_TAG%" "%README_INPUT%" >nul
if not errorlevel 1 (set "FAIL_REASON=README still contains PREVIOUS_TAG."& set "FAIL_CODE=42"& goto :Fail)

set "STEP=output collision checks"
if exist "%WORK%" (set "FAIL_REASON=Release work directory already exists."& set "FAIL_CODE=50"& goto :Fail)
if exist "%FINAL_ZIP%" (set "FAIL_REASON=Final ZIP already exists."& set "FAIL_CODE=51"& goto :Fail)
if not exist "%WORK_ROOT%" mkdir "%WORK_ROOT%"
if errorlevel 1 (set "FAIL_REASON=Could not create release-work."& set "FAIL_CODE=52"& goto :Fail)
if not exist "%ARTIFACTS%" mkdir "%ARTIFACTS%"
if errorlevel 1 (set "FAIL_REASON=Could not create release-artifacts."& set "FAIL_CODE=53"& goto :Fail)
mkdir "%STAGING%"
if errorlevel 1 (set "FAIL_REASON=Could not create new staging directory."& set "FAIL_CODE=54"& goto :Fail)

set "STEP=previous Release metadata"
curl.exe -L --fail --silent --show-error -H "Accept: application/vnd.github+json" -o "%API_JSON%" "https://api.github.com/repos/snow-1024zzz/SnowRoles-Releases/releases/tags/%PREVIOUS_TAG%"
if errorlevel 1 (set "FAIL_REASON=Could not obtain previous Release metadata."& set "FAIL_CODE=60"& goto :Fail)
set "ASSET_COUNT=0"
set "ASSET_NAME_COUNT=0"
set "TAG_NAME_COUNT=0"
set "PRERELEASE_COUNT=0"
set "EXPECTED_URL_COUNT=0"
set "STATE_COUNT=0"
set "SIZE_COUNT=0"
set "DIGEST_COUNT=0"
set "API_TAG="
set "API_PRERELEASE="
set "API_ASSET_NAME="
set "API_ASSET_URL="
set "API_ASSET_STATE="
set "API_ASSET_SIZE="
set "API_ASSET_DIGEST="
for /f "usebackq delims=" %%A in ("%API_JSON%") do (
  set "JSON_LINE=%%A"
  for /f "tokens=1,* delims=:" %%K in ("!JSON_LINE!") do (
    set "JSON_KEY=%%K"
    set "JSON_VALUE=%%L"
    set "JSON_KEY=!JSON_KEY:"=!"
    set "JSON_VALUE=!JSON_VALUE:"=!"
    set "JSON_VALUE=!JSON_VALUE:,=!"
    set "JSON_VALUE=!JSON_VALUE: =!"
    if "!JSON_KEY!"=="  tag_name" (
      set /a TAG_NAME_COUNT+=1
      set "API_TAG=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="  prerelease" (
      set /a PRERELEASE_COUNT+=1
      set "API_PRERELEASE=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      url" set /a ASSET_COUNT+=1
    if "!JSON_KEY!"=="      name" (
      set /a ASSET_NAME_COUNT+=1
      set "API_ASSET_NAME=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      browser_download_url" (
      set /a EXPECTED_URL_COUNT+=1
      set "API_ASSET_URL=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      state" (
      set /a STATE_COUNT+=1
      set "API_ASSET_STATE=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      size" (
      set /a SIZE_COUNT+=1
      set "API_ASSET_SIZE=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      digest" (
      set /a DIGEST_COUNT+=1
      set "API_ASSET_DIGEST=!JSON_VALUE:sha256:=!"
    )
  )
)
if not "%TAG_NAME_COUNT%"=="1" (set "FAIL_REASON=Previous Release tag_name is not unique."& set "FAIL_CODE=61"& goto :Fail)
if /i not "%API_TAG%"=="%PREVIOUS_TAG%" (set "FAIL_REASON=Previous Release tag_name mismatch."& set "FAIL_CODE=62"& goto :Fail)
if not "%PRERELEASE_COUNT%"=="1" (set "FAIL_REASON=Previous Release prerelease field is not unique."& set "FAIL_CODE=63"& goto :Fail)
if /i not "%API_PRERELEASE%"=="true" (set "FAIL_REASON=Previous Release is not a prerelease."& set "FAIL_CODE=64"& goto :Fail)
if not "%ASSET_COUNT%"=="1" (set "FAIL_REASON=Previous Release must contain exactly one Asset."& set "FAIL_CODE=65"& goto :Fail)
if not "%ASSET_NAME_COUNT%"=="1" (set "FAIL_REASON=Previous Asset name is not unique."& set "FAIL_CODE=66"& goto :Fail)
if /i not "%API_ASSET_NAME%"=="%PREVIOUS_ZIP_NAME%" (set "FAIL_REASON=Expected previous ZIP Asset was not found."& set "FAIL_CODE=67"& goto :Fail)
if not "%EXPECTED_URL_COUNT%"=="1" (set "FAIL_REASON=Previous Asset browser_download_url is not unique."& set "FAIL_CODE=68"& goto :Fail)
if /i not "%API_ASSET_URL%"=="https://github.com/snow-1024zzz/SnowRoles-Releases/releases/download/%PREVIOUS_TAG%/%PREVIOUS_ZIP_NAME%" (set "FAIL_REASON=Previous Asset browser_download_url mismatch."& set "FAIL_CODE=69"& goto :Fail)
if not "%STATE_COUNT%"=="1" (set "FAIL_REASON=Previous Asset state is not unique."& set "FAIL_CODE=70"& goto :Fail)
if /i not "%API_ASSET_STATE%"=="uploaded" (set "FAIL_REASON=Previous Asset state is not uploaded."& set "FAIL_CODE=71"& goto :Fail)
if not "%SIZE_COUNT%"=="1" (set "FAIL_REASON=Previous Asset size is not unique."& set "FAIL_CODE=72"& goto :Fail)
if not "%DIGEST_COUNT%"=="1" (set "FAIL_REASON=Previous Asset digest is not unique."& set "FAIL_CODE=73"& goto :Fail)
if not defined API_ASSET_SIZE (set "FAIL_REASON=Previous Asset size was not parsed."& set "FAIL_CODE=74"& goto :Fail)
if not defined API_ASSET_DIGEST (set "FAIL_REASON=Previous Asset digest was not parsed."& set "FAIL_CODE=75"& goto :Fail)
call :ValidateHash "%API_ASSET_DIGEST%"
if errorlevel 1 (set "FAIL_REASON=Previous Asset digest is invalid."& set "FAIL_CODE=76"& goto :Fail)

set "STEP=previous ZIP acquisition"
if exist "%PREVIOUS_LOCAL%" (
  set "PREVIOUS_ZIP=%PREVIOUS_LOCAL%"
) else (
  curl.exe -L --fail --silent --show-error -o "%PREVIOUS_DOWNLOAD%" "https://github.com/snow-1024zzz/SnowRoles-Releases/releases/download/%PREVIOUS_TAG%/%PREVIOUS_ZIP_NAME%"
  if errorlevel 1 (set "FAIL_REASON=Could not download previous ZIP."& set "FAIL_CODE=70"& goto :Fail)
  set "PREVIOUS_ZIP=%PREVIOUS_DOWNLOAD%"
)
for %%F in ("!PREVIOUS_ZIP!") do set "PREVIOUS_ZIP_SIZE=%%~zF"
call :GetHash "!PREVIOUS_ZIP!" PREVIOUS_ZIP_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash previous ZIP."& set "FAIL_CODE=71"& goto :Fail)
if not "!PREVIOUS_ZIP_SIZE!"=="%API_ASSET_SIZE%" (set "FAIL_REASON=Previous ZIP size does not match Public metadata."& set "FAIL_CODE=72"& goto :Fail)
if /i not "!PREVIOUS_ZIP_HASH!"=="%API_ASSET_DIGEST%" (set "FAIL_REASON=Previous ZIP hash does not match Public metadata."& set "FAIL_CODE=73"& goto :Fail)

set "STEP=previous ZIP extraction"
tar.exe -xf "!PREVIOUS_ZIP!" -C "%STAGING%"
if errorlevel 1 (set "FAIL_REASON=Could not extract previous ZIP."& set "FAIL_CODE=80"& goto :Fail)

set "STEP=staging top-level validation"
set "TOP_COUNT=0"
for /f "delims=" %%E in ('dir /a /b "%STAGING%"') do set /a TOP_COUNT+=1
if not "%TOP_COUNT%"=="8" (set "FAIL_REASON=Unexpected staging top-level item count."& set "FAIL_CODE=81"& goto :Fail)
for %%F in (.doorstop_version doorstop_config.ini README.txt SHA256SUMS.txt winhttp.dll) do if not exist "%STAGING%\%%F" (set "FAIL_REASON=Missing required top-level file %%F."& set "FAIL_CODE=82"& goto :Fail)
for %%F in (.doorstop_version doorstop_config.ini README.txt SHA256SUMS.txt winhttp.dll) do if exist "%STAGING%\%%F\" (set "FAIL_REASON=Expected a file but found a directory: %%F."& set "FAIL_CODE=83"& goto :Fail)
for %%D in (BepInEx dotnet licenses) do if not exist "%STAGING%\%%D\" (set "FAIL_REASON=Missing required top-level directory %%D."& set "FAIL_CODE=84"& goto :Fail)
for %%D in (BepInEx dotnet licenses) do if exist "%STAGING%\%%D" if not exist "%STAGING%\%%D\" (set "FAIL_REASON=Expected a directory but found a file: %%D."& set "FAIL_CODE=85"& goto :Fail)
setlocal DisableDelayedExpansion
dir /a /b /s "%STAGING%" | findstr /l /c:"!" >nul
set "BANG_PATH_RC=%ERRORLEVEL%"
endlocal & set "BANG_PATH_RC=%BANG_PATH_RC%"
if "%BANG_PATH_RC%"=="0" (set "FAIL_REASON=Staging paths containing ! are not supported."& set "FAIL_CODE=86"& goto :Fail)

set "STEP=DLL and README replacement"
copy /b /y "%SOURCE_DLL%" "%STAGING%\BepInEx\plugins\SnowRoles.dll" >nul
if errorlevel 1 (set "FAIL_REASON=Could not replace staging SnowRoles.dll."& set "FAIL_CODE=90"& goto :Fail)
for %%F in ("%STAGING%\BepInEx\plugins\SnowRoles.dll") do set "STAGING_DLL_SIZE=%%~zF"
call :GetHash "%STAGING%\BepInEx\plugins\SnowRoles.dll" STAGING_DLL_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash staging SnowRoles.dll."& set "FAIL_CODE=91"& goto :Fail)
if not "%SOURCE_DLL_SIZE%"=="%STAGING_DLL_SIZE%" (set "FAIL_REASON=Staging DLL size mismatch."& set "FAIL_CODE=92"& goto :Fail)
if /i not "%SOURCE_DLL_HASH%"=="%STAGING_DLL_HASH%" (set "FAIL_REASON=Staging DLL hash mismatch."& set "FAIL_CODE=93"& goto :Fail)
copy /b /y "%README_INPUT%" "%STAGING%\README.txt" >nul
if errorlevel 1 (set "FAIL_REASON=Could not replace staging README.txt."& set "FAIL_CODE=94"& goto :Fail)
call :GetHash "%STAGING%\README.txt" README_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash staging README.txt."& set "FAIL_CODE=95"& goto :Fail)
call :GetHash "%STAGING%\BepInEx\plugins\Reactor.dll" REACTOR_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash staging Reactor.dll."& set "FAIL_CODE=96"& goto :Fail)

set "STEP=SHA256SUMS generation"
if exist "%NEW_SUMS%" (set "FAIL_REASON=Temporary SHA256SUMS output already exists."& set "FAIL_CODE=100"& goto :Fail)
type nul > "%NEW_SUMS%"
set "FILE_COUNT=0"
for /f "delims=" %%F in ('dir /a-d /b /s "%STAGING%" ^| sort') do (
  if /i not "%%F"=="%STAGING%\SHA256SUMS.txt" (
    set /a FILE_COUNT+=1
    set "REL=%%F"
    set "REL=!REL:%STAGING%\=!"
    set "HASH="
    for /f "delims=" %%H in ('certutil -hashfile "%%F" SHA256 ^| findstr /r "^[0-9a-f][0-9a-f]*$"') do set "HASH=%%H"
    call :ValidateHash "!HASH!"
    if errorlevel 1 (set "FAIL_REASON=Hash generation failed for %%F."& set "FAIL_CODE=101"& goto :Fail)
    >>"%NEW_SUMS%" echo !HASH!  !REL:\=/!
  )
)
for /f %%C in ('find /v /c "" ^< "%NEW_SUMS%"') do set "SUM_LINE_COUNT=%%C"
if not "%FILE_COUNT%"=="%SUM_LINE_COUNT%" (set "FAIL_REASON=File count and SHA256SUMS line count differ."& set "FAIL_CODE=102"& goto :Fail)
findstr /x /l /c:"%SOURCE_DLL_HASH%  BepInEx/plugins/SnowRoles.dll" "%NEW_SUMS%" >nul
if errorlevel 1 (set "FAIL_REASON=SnowRoles.dll entry validation failed."& set "FAIL_CODE=103"& goto :Fail)
findstr /x /l /c:"%README_HASH%  README.txt" "%NEW_SUMS%" >nul
if errorlevel 1 (set "FAIL_REASON=README.txt entry validation failed."& set "FAIL_CODE=104"& goto :Fail)
findstr /x /l /c:"%REACTOR_HASH%  BepInEx/plugins/Reactor.dll" "%NEW_SUMS%" >nul
if errorlevel 1 (set "FAIL_REASON=Reactor.dll entry validation failed."& set "FAIL_CODE=105"& goto :Fail)
copy /b /y "%NEW_SUMS%" "%STAGING%\SHA256SUMS.txt" >nul
if errorlevel 1 (set "FAIL_REASON=Could not install SHA256SUMS.txt."& set "FAIL_CODE=106"& goto :Fail)
for %%F in ("%NEW_SUMS%") do set "NEW_SUMS_SIZE=%%~zF"
for %%F in ("%STAGING%\SHA256SUMS.txt") do set "STAGING_SUMS_SIZE=%%~zF"
call :GetHash "%NEW_SUMS%" NEW_SUMS_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash temporary SHA256SUMS."& set "FAIL_CODE=107"& goto :Fail)
call :GetHash "%STAGING%\SHA256SUMS.txt" STAGING_SUMS_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash staging SHA256SUMS."& set "FAIL_CODE=108"& goto :Fail)
if not "%NEW_SUMS_SIZE%"=="%STAGING_SUMS_SIZE%" (set "FAIL_REASON=SHA256SUMS copy size mismatch."& set "FAIL_CODE=109"& goto :Fail)
if /i not "%NEW_SUMS_HASH%"=="%STAGING_SUMS_HASH%" (set "FAIL_REASON=SHA256SUMS copy hash mismatch."& set "FAIL_CODE=110"& goto :Fail)

set "STEP=final ZIP creation"
tar.exe -a -cf "%FINAL_ZIP%" -C "%STAGING%" .doorstop_version doorstop_config.ini README.txt SHA256SUMS.txt winhttp.dll BepInEx dotnet licenses
if errorlevel 1 (set "FAIL_REASON=Could not create final ZIP."& set "FAIL_CODE=120"& goto :Fail)
if not exist "%FINAL_ZIP%" (set "FAIL_REASON=Final ZIP does not exist."& set "FAIL_CODE=121"& goto :Fail)
for %%F in ("%FINAL_ZIP%") do set "FINAL_ZIP_SIZE=%%~zF"
call :GetHash "%FINAL_ZIP%" FINAL_ZIP_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash final ZIP."& set "FAIL_CODE=122"& goto :Fail)

set "STEP=final ZIP validation"
tar.exe -tf "%FINAL_ZIP%" > "%ZIP_LIST%"
if errorlevel 1 (set "FAIL_REASON=Could not list final ZIP."& set "FAIL_CODE=123"& goto :Fail)
findstr /x /l /c:"BepInEx/plugins/SnowRoles.dll" "%ZIP_LIST%" >nul
if errorlevel 1 (set "FAIL_REASON=Final ZIP lacks SnowRoles.dll."& set "FAIL_CODE=124"& goto :Fail)
findstr /x /l /c:"BepInEx/plugins/Reactor.dll" "%ZIP_LIST%" >nul
if errorlevel 1 (set "FAIL_REASON=Final ZIP lacks Reactor.dll."& set "FAIL_CODE=125"& goto :Fail)
findstr /x /l /c:"README.txt" "%ZIP_LIST%" >nul
if errorlevel 1 (set "FAIL_REASON=Final ZIP lacks README.txt."& set "FAIL_CODE=126"& goto :Fail)
findstr /x /l /c:"SHA256SUMS.txt" "%ZIP_LIST%" >nul
if errorlevel 1 (set "FAIL_REASON=Final ZIP lacks SHA256SUMS.txt."& set "FAIL_CODE=127"& goto :Fail)
findstr /b /l /c:"staging/" "%ZIP_LIST%" >nul
if not errorlevel 1 (set "FAIL_REASON=Final ZIP contains staging parent directory."& set "FAIL_CODE=128"& goto :Fail)
findstr /b /l /c:"release-work/" "%ZIP_LIST%" >nul
if not errorlevel 1 (set "FAIL_REASON=Final ZIP contains release-work parent directory."& set "FAIL_CODE=129"& goto :Fail)
findstr /b /l /c:"%NEW_TAG%/" "%ZIP_LIST%" >nul
if not errorlevel 1 (set "FAIL_REASON=Final ZIP contains NEW_TAG parent directory."& set "FAIL_CODE=130"& goto :Fail)

set "STEP=release summary"
if exist "%SUMMARY%" (set "FAIL_REASON=Release summary already exists."& set "FAIL_CODE=140"& goto :Fail)
(
  echo NEW_TAG=%NEW_TAG%
  echo PREVIOUS_TAG=%PREVIOUS_TAG%
  echo Source commit=%SOURCE_COMMIT%
  echo Source DLL Size=%SOURCE_DLL_SIZE%
  echo Source DLL SHA-256=%SOURCE_DLL_HASH%
  echo README SHA-256=%README_HASH%
  echo SHA256SUMS SHA-256=%STAGING_SUMS_HASH%
  echo Final ZIP Filename=%FINAL_ZIP_NAME%
  echo Final ZIP Size=%FINAL_ZIP_SIZE%
  echo Final ZIP SHA-256=%FINAL_ZIP_HASH%
) > "%SUMMARY%"
if errorlevel 1 (set "FAIL_REASON=Could not create release summary."& set "FAIL_CODE=141"& goto :Fail)

echo.
echo PREPARE TEST RELEASE = PASS
echo Summary: %SUMMARY%
echo Final ZIP: %FINAL_ZIP%
exit /b 0

:Usage
echo Usage: %~nx0 NEW_TAG PREVIOUS_TAG
exit /b 2

:ValidateTag
set "CHECK_TAG=%~1"
if not defined CHECK_TAG exit /b 1
set "TAG_MAJOR="
set "TAG_MINOR="
set "TAG_PATCH="
set "TAG_WORD="
set "TAG_TEST="
for /f "tokens=1-5 delims=.-" %%A in ("%CHECK_TAG:~1%") do (
  set "TAG_MAJOR=%%A"
  set "TAG_MINOR=%%B"
  set "TAG_PATCH=%%C"
  set "TAG_WORD=%%D"
  set "TAG_TEST=%%E"
)
for %%N in ("!TAG_MAJOR!" "!TAG_MINOR!" "!TAG_PATCH!" "!TAG_TEST!") do (
  if "%%~N"=="" exit /b 1
  echo(%%~N| findstr /r "[^0-9]" >nul && exit /b 1
)
if not "!TAG_WORD!"=="test" exit /b 1
if not "%CHECK_TAG%"=="v!TAG_MAJOR!.!TAG_MINOR!.!TAG_PATCH!-test.!TAG_TEST!" exit /b 1
exit /b 0

:ValidateHash
set "CHECK_HASH=%~1"
if "%CHECK_HASH:~63,1%"=="" exit /b 1
if not "%CHECK_HASH:~64,1%"=="" exit /b 1
echo(%CHECK_HASH%| findstr /r /x "[0-9a-f][0-9a-f]*" >nul
exit /b %ERRORLEVEL%

:GetHash
set "%~2="
for /f "delims=" %%H in ('certutil -hashfile "%~1" SHA256 ^| findstr /r "^[0-9a-f][0-9a-f]*$"') do set "%~2=%%H"
call :ValidateHash "!%~2!"
exit /b %ERRORLEVEL%

:Fail
echo.
echo PREPARE TEST RELEASE = FAIL
echo Step: %STEP%
echo Reason: %FAIL_REASON%
exit /b %FAIL_CODE%
