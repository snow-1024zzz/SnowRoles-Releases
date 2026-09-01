@echo off
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="" goto :Usage
if not "%~2"=="" goto :Usage
set "TAG=%~1"
call :ValidateTag "%TAG%"
if errorlevel 1 (set "FAIL_REASON=Invalid TAG."& set "FAIL_CODE=10"& goto :Fail)
set "RELEASE_REPO=C:\AmongUsMod\SnowRoles-Releases"
set "ARTIFACT=C:\AmongUsMod\release-artifacts\SnowRoles-%TAG%-Steam.zip"
set "SUMMARY=C:\AmongUsMod\release-work\%TAG%\RELEASE_SUMMARY.txt"
set "EXPECTED_ORIGIN=https://github.com/snow-1024zzz/SnowRoles-Releases.git"

git -C "%RELEASE_REPO%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (set "FAIL_REASON=Release repository is not a Git work tree."& set "FAIL_CODE=20"& goto :Fail)
for /f "delims=" %%B in ('git -C "%RELEASE_REPO%" branch --show-current') do set "BRANCH=%%B"
if not "%BRANCH%"=="main" (set "FAIL_REASON=Current branch is not main."& set "FAIL_CODE=21"& goto :Fail)
for /f "delims=" %%S in ('git -C "%RELEASE_REPO%" status --porcelain') do set "REPO_DIRTY=1"
if defined REPO_DIRTY (set "FAIL_REASON=Release repository is not clean."& set "FAIL_CODE=22"& goto :Fail)
for /f "delims=" %%U in ('git -C "%RELEASE_REPO%" config --get remote.origin.url') do set "ORIGIN_URL=%%U"
if /i not "%ORIGIN_URL%"=="%EXPECTED_ORIGIN%" (set "FAIL_REASON=origin URL mismatch."& set "FAIL_CODE=23"& goto :Fail)
for /f "delims=" %%H in ('git -C "%RELEASE_REPO%" rev-parse HEAD') do set "LOCAL_HEAD=%%H"
if not defined LOCAL_HEAD (set "FAIL_REASON=Could not read local HEAD."& set "FAIL_CODE=24"& goto :Fail)
for /f "tokens=1" %%H in ('git -C "%RELEASE_REPO%" ls-remote origin refs/heads/main') do set "REMOTE_MAIN=%%H"
if not defined REMOTE_MAIN (set "FAIL_REASON=Could not read remote main."& set "FAIL_CODE=25"& goto :Fail)
if /i not "%LOCAL_HEAD%"=="%REMOTE_MAIN%" (set "FAIL_REASON=Local HEAD differs from remote main."& set "FAIL_CODE=26"& goto :Fail)
for /f "delims=" %%T in ('git -C "%RELEASE_REPO%" tag --list "%TAG%"') do set "LOCAL_TAG_EXISTS=1"
if defined LOCAL_TAG_EXISTS (set "FAIL_REASON=Local TAG already exists."& set "FAIL_CODE=30"& goto :Fail)
git -C "%RELEASE_REPO%" ls-remote --exit-code --tags origin "refs/tags/%TAG%" >nul 2>nul
set "REMOTE_TAG_RC=%ERRORLEVEL%"
if "%REMOTE_TAG_RC%"=="0" (set "FAIL_REASON=Remote TAG already exists."& set "FAIL_CODE=31"& goto :Fail)
if not "%REMOTE_TAG_RC%"=="2" (set "FAIL_REASON=Remote TAG check failed unexpectedly."& set "FAIL_CODE=32"& goto :Fail)
if not exist "%ARTIFACT%" (set "FAIL_REASON=Release Artifact does not exist."& set "FAIL_CODE=33"& goto :Fail)
if not exist "%SUMMARY%" (set "FAIL_REASON=RELEASE_SUMMARY.txt does not exist."& set "FAIL_CODE=34"& goto :Fail)

git -C "%RELEASE_REPO%" tag "%TAG%" "%LOCAL_HEAD%"
if errorlevel 1 (set "FAIL_REASON=Lightweight tag creation failed."& set "FAIL_CODE=40"& goto :Fail)
git -C "%RELEASE_REPO%" push origin "refs/tags/%TAG%"
if errorlevel 1 (set "FAIL_REASON=Tag push failed. The local tag is retained."& set "FAIL_CODE=41"& goto :Fail)
set "REMOTE_TAG_SHA="
for /f "tokens=1" %%H in ('git -C "%RELEASE_REPO%" ls-remote --tags origin "refs/tags/%TAG%"') do set "REMOTE_TAG_SHA=%%H"
if not defined REMOTE_TAG_SHA (set "FAIL_REASON=Remote tag verification returned no ref."& set "FAIL_CODE=42"& goto :Fail)
if /i not "%REMOTE_TAG_SHA%"=="%LOCAL_HEAD%" (set "FAIL_REASON=Remote tag SHA mismatch."& set "FAIL_CODE=43"& goto :Fail)
echo.
echo PUSH TEST TAG = PASS
echo TAG=%TAG%
echo SHA=%REMOTE_TAG_SHA%
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

:Fail
echo.
echo PUSH TEST TAG = FAIL
echo Reason: %FAIL_REASON%
exit /b %FAIL_CODE%
