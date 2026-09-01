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

set "TAG_MATCH=0"
set "PRERELEASE_MATCH=0"
set "ASSET_COUNT=0"
set "ASSET_FOUND=0"
set "ASSET_STATE_MATCH=0"
set "TAG_NAME_COUNT=0"
set "PRERELEASE_COUNT=0"
set "EXPECTED_URL_COUNT=0"
set "STATE_COUNT=0"
set "SIZE_COUNT=0"
set "DIGEST_COUNT=0"
set "API_SIZE="
set "API_DIGEST="
for /f "usebackq delims=" %%L in ("%API_JSON%") do (
  set "LINE=%%L"
  echo(!LINE!^| findstr /l /c:"tag_name" >nul && (
    set /a TAG_NAME_COUNT+=1
    set "API_TAG=!LINE:*:=!"
    set "API_TAG=!API_TAG:"=!"
    set "API_TAG=!API_TAG:,=!"
    set "API_TAG=!API_TAG: =!"
    if /i "!API_TAG!"=="%TAG%" set "TAG_MATCH=1"
  )
  echo(!LINE!^| findstr /l /c:"prerelease" >nul && (
    set /a PRERELEASE_COUNT+=1
    echo(!LINE!^| findstr /l /c:"true" >nul && set "PRERELEASE_MATCH=1"
  )
  echo(!LINE!^| findstr /l /c:"browser_download_url" >nul && set /a ASSET_COUNT+=1
  echo(!LINE!^| findstr /l /c:"https://github.com/snow-1024zzz/SnowRoles-Releases/releases/download/%TAG%/%ZIP_NAME%" >nul && set /a EXPECTED_URL_COUNT+=1
  echo(!LINE!^| findstr /l /c:"state" >nul && (
    set /a STATE_COUNT+=1
    echo(!LINE!^| findstr /l /c:"uploaded" >nul && set "ASSET_STATE_MATCH=1"
  )
  echo(!LINE!^| findstr /l /c:"size" >nul && (
    set /a SIZE_COUNT+=1
    set "API_SIZE=!LINE:*:=!"
    set "API_SIZE=!API_SIZE:,=!"
    set "API_SIZE=!API_SIZE: =!"
  )
  echo(!LINE!^| findstr /l /c:"digest" >nul && (
    set /a DIGEST_COUNT+=1
    set "API_DIGEST=!LINE:*sha256:=!"
    set "API_DIGEST=!API_DIGEST:"=!"
    set "API_DIGEST=!API_DIGEST:,=!"
    set "API_DIGEST=!API_DIGEST: =!"
  )
  if "!ASSET_FOUND!"=="0" (
    echo(!LINE!^| findstr /l /c:"%ZIP_NAME%" >nul && (
      set "API_ASSET_NAME=!LINE:*:=!"
      set "API_ASSET_NAME=!API_ASSET_NAME:"=!"
      set "API_ASSET_NAME=!API_ASSET_NAME:,=!"
      set "API_ASSET_NAME=!API_ASSET_NAME: =!"
      if /i "!API_ASSET_NAME!"=="%ZIP_NAME%" set "ASSET_FOUND=1"
    )
  ) else (
    echo(!LINE!^| findstr /l /c:"state" >nul && echo(!LINE!^| findstr /l /c:"uploaded" >nul && set "ASSET_STATE_MATCH=1"
    if not defined API_SIZE (
      echo(!LINE!^| findstr /l /c:"size" >nul && (
        set "API_SIZE=!LINE:*:=!"
        set "API_SIZE=!API_SIZE:,=!"
        set "API_SIZE=!API_SIZE: =!"
      )
    )
    if not defined API_DIGEST (
      echo(!LINE!^| findstr /l /c:"digest" >nul && (
        set "API_DIGEST=!LINE:*sha256:=!"
        set "API_DIGEST=!API_DIGEST:"=!"
        set "API_DIGEST=!API_DIGEST:,=!"
        set "API_DIGEST=!API_DIGEST: =!"
      )
    )
  )
)
if not "%TAG_NAME_COUNT%"=="1" (set "FAIL_REASON=tag_name is not unique."& set "FAIL_CODE=29"& goto :Fail)
if not "%TAG_MATCH%"=="1" (set "FAIL_REASON=tag_name mismatch."& set "FAIL_CODE=30"& goto :Fail)
if not "%PRERELEASE_COUNT%"=="1" (set "FAIL_REASON=prerelease field is not unique."& set "FAIL_CODE=31"& goto :Fail)
if not "%PRERELEASE_MATCH%"=="1" (set "FAIL_REASON=Release is not marked prerelease."& set "FAIL_CODE=31"& goto :Fail)
if not "%ASSET_COUNT%"=="1" (set "FAIL_REASON=Release must contain exactly one Asset."& set "FAIL_CODE=32"& goto :Fail)
if not "%ASSET_FOUND%"=="1" (set "FAIL_REASON=Expected Asset filename was not found."& set "FAIL_CODE=33"& goto :Fail)
if not "%EXPECTED_URL_COUNT%"=="1" (set "FAIL_REASON=Expected browser_download_url is not unique."& set "FAIL_CODE=34"& goto :Fail)
if not "%STATE_COUNT%"=="1" (set "FAIL_REASON=Asset state is not unique."& set "FAIL_CODE=35"& goto :Fail)
if not "%ASSET_STATE_MATCH%"=="1" (set "FAIL_REASON=Asset state is not uploaded."& set "FAIL_CODE=34"& goto :Fail)
if not "%SIZE_COUNT%"=="1" (set "FAIL_REASON=Asset size is not unique."& set "FAIL_CODE=35"& goto :Fail)
if not "%DIGEST_COUNT%"=="1" (set "FAIL_REASON=Asset digest is not unique."& set "FAIL_CODE=36"& goto :Fail)
if not defined API_SIZE (set "FAIL_REASON=Asset size was not parsed."& set "FAIL_CODE=35"& goto :Fail)
if not defined API_DIGEST (set "FAIL_REASON=Asset digest was not parsed."& set "FAIL_CODE=36"& goto :Fail)
call :ValidateHash "%API_DIGEST%"
if errorlevel 1 (set "FAIL_REASON=Asset digest is invalid."& set "FAIL_CODE=37"& goto :Fail)
if not "%API_SIZE%"=="%LOCAL_SIZE%" (set "FAIL_REASON=Asset size differs from Local ZIP."& set "FAIL_CODE=38"& goto :Fail)
if /i not "%API_DIGEST%"=="%LOCAL_HASH%" (set "FAIL_REASON=Asset digest differs from Local ZIP."& set "FAIL_CODE=39"& goto :Fail)
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
