@echo off
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" goto :Usage
if not "%~2"=="" goto :Usage
set "TAG=%~1"
call :ValidateTag "%TAG%"
if errorlevel 1 (set "FAIL_REASON=Invalid TAG."& set "FAIL_CODE=10"& goto :Fail)
set "ZIP_NAME=SnowRoles-%TAG%-Steam.zip"
set "LOCAL_ZIP=C:\AmongUsMod\release-artifacts\%ZIP_NAME%"
set "API_JSON=C:\AmongUsMod\release-work\%TAG%\public-release.json"
if not exist "%LOCAL_ZIP%" (set "FAIL_REASON=Local Release ZIP does not exist."& set "FAIL_CODE=20"& goto :Fail)
if exist "%API_JSON%" (set "FAIL_REASON=Public Release metadata output already exists."& set "FAIL_CODE=21"& goto :Fail)
for %%F in ("%LOCAL_ZIP%") do set "LOCAL_SIZE=%%~zF"
call :GetHash "%LOCAL_ZIP%" LOCAL_HASH
if errorlevel 1 (set "FAIL_REASON=Could not hash Local ZIP."& set "FAIL_CODE=22"& goto :Fail)

curl.exe -L --fail --silent --show-error -H "Accept: application/vnd.github+json" -o "%API_JSON%" "https://api.github.com/repos/snow-1024zzz/SnowRoles-Releases/releases/tags/%TAG%"
if errorlevel 1 (set "FAIL_REASON=Public Release API request failed."& set "FAIL_CODE=23"& goto :Fail)

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
set "API_SIZE="
set "API_DIGEST="
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
      set "API_SIZE=!JSON_VALUE!"
    )
    if "!JSON_KEY!"=="      digest" (
      set /a DIGEST_COUNT+=1
      set "API_DIGEST=!JSON_VALUE:sha256:=!"
    )
  )
)
if not "%TAG_NAME_COUNT%"=="1" (set "FAIL_REASON=tag_name is not unique."& set "FAIL_CODE=29"& goto :Fail)
if /i not "%API_TAG%"=="%TAG%" (set "FAIL_REASON=tag_name mismatch."& set "FAIL_CODE=30"& goto :Fail)
if not "%PRERELEASE_COUNT%"=="1" (set "FAIL_REASON=prerelease field is not unique."& set "FAIL_CODE=31"& goto :Fail)
if /i not "%API_PRERELEASE%"=="true" (set "FAIL_REASON=Release is not marked prerelease."& set "FAIL_CODE=31"& goto :Fail)
if not "%ASSET_COUNT%"=="1" (set "FAIL_REASON=Release must contain exactly one Asset."& set "FAIL_CODE=32"& goto :Fail)
if not "%ASSET_NAME_COUNT%"=="1" (set "FAIL_REASON=Asset name is not unique."& set "FAIL_CODE=33"& goto :Fail)
if /i not "%API_ASSET_NAME%"=="%ZIP_NAME%" (set "FAIL_REASON=Expected Asset filename was not found."& set "FAIL_CODE=34"& goto :Fail)
if not "%EXPECTED_URL_COUNT%"=="1" (set "FAIL_REASON=Expected browser_download_url is not unique."& set "FAIL_CODE=35"& goto :Fail)
if /i not "%API_ASSET_URL%"=="https://github.com/snow-1024zzz/SnowRoles-Releases/releases/download/%TAG%/%ZIP_NAME%" (set "FAIL_REASON=Asset browser_download_url mismatch."& set "FAIL_CODE=36"& goto :Fail)
if not "%STATE_COUNT%"=="1" (set "FAIL_REASON=Asset state is not unique."& set "FAIL_CODE=37"& goto :Fail)
if /i not "%API_ASSET_STATE%"=="uploaded" (set "FAIL_REASON=Asset state is not uploaded."& set "FAIL_CODE=38"& goto :Fail)
if not "%SIZE_COUNT%"=="1" (set "FAIL_REASON=Asset size is not unique."& set "FAIL_CODE=39"& goto :Fail)
if not "%DIGEST_COUNT%"=="1" (set "FAIL_REASON=Asset digest is not unique."& set "FAIL_CODE=40"& goto :Fail)
if not defined API_SIZE (set "FAIL_REASON=Asset size was not parsed."& set "FAIL_CODE=41"& goto :Fail)
if not defined API_DIGEST (set "FAIL_REASON=Asset digest was not parsed."& set "FAIL_CODE=42"& goto :Fail)
call :ValidateHash "%API_DIGEST%"
if errorlevel 1 (set "FAIL_REASON=Asset digest is invalid."& set "FAIL_CODE=43"& goto :Fail)
if not "%API_SIZE%"=="%LOCAL_SIZE%" (set "FAIL_REASON=Asset size differs from Local ZIP."& set "FAIL_CODE=44"& goto :Fail)
if /i not "%API_DIGEST%"=="%LOCAL_HASH%" (set "FAIL_REASON=Asset digest differs from Local ZIP."& set "FAIL_CODE=45"& goto :Fail)
echo.
echo PUBLIC RELEASE VERIFY = PASS
echo TAG=%TAG%
echo Asset=%ZIP_NAME%
echo Size=%LOCAL_SIZE%
echo SHA-256=%LOCAL_HASH%
exit /b 0

:Usage
echo Usage: %~nx0 TAG
exit /b 2

:ValidateTag
set "CHECK_TAG=%~1"
if not defined CHECK_TAG exit /b 1
set "TAG_MAJOR="
set "TAG_MINOR="
set "TAG_PATCH="
set "TAG_WORD="
set "TAG_TEST="
for /f "tokens=1-5 delims=.-" %%A in ("%CHECK_TAG:~1%") do set "TAG_MAJOR=%%A"& set "TAG_MINOR=%%B"& set "TAG_PATCH=%%C"& set "TAG_WORD=%%D"& set "TAG_TEST=%%E"
for %%N in ("!TAG_MAJOR!" "!TAG_MINOR!" "!TAG_PATCH!" "!TAG_TEST!") do if "%%~N"=="" exit /b 1
for %%N in ("!TAG_MAJOR!" "!TAG_MINOR!" "!TAG_PATCH!" "!TAG_TEST!") do echo(%%~N| findstr /r "[^0-9]" >nul && exit /b 1
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
echo PUBLIC RELEASE VERIFY = FAIL
echo Reason: %FAIL_REASON%
exit /b %FAIL_CODE%
