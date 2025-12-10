@echo off
echo 🚀 Arcular+ Version Manager
echo ================================

if "%1"=="" (
    echo Usage: version_update.bat [command] [description]
    echo.
    echo Commands:
    echo   current              - Show current version
    echo   patch [description]  - Increment patch version (bug fixes)
    echo   minor [description]  - Increment minor version (new features)
    echo   major [description]  - Increment major version (breaking changes)
    echo.
    echo Examples:
    echo   version_update.bat current
    echo   version_update.bat patch "Fixed login issue"
    echo   version_update.bat minor "Added nurse features"
    echo   version_update.bat major "Complete redesign"
    goto :eof
)

if "%1"=="current" (
    python version_manager.py current
    goto :eof
)

if "%1"=="patch" (
    python version_manager.py patch "%2 %3 %4 %5 %6 %7 %8 %9"
    goto :build
)

if "%1"=="minor" (
    python version_manager.py minor "%2 %3 %4 %5 %6 %7 %8 %9"
    goto :build
)

if "%1"=="major" (
    python version_manager.py major "%2 %3 %4 %5 %6 %7 %8 %9"
    goto :build
)

echo ❌ Unknown command: %1
echo Use: version_update.bat current, patch, minor, or major
goto :eof

:build
echo.
echo 🎯 Do you want to build the APK now? (Y/N)
set /p choice=
if /i "%choice%"=="Y" (
    echo.
    echo 🔨 Building APK...
    flutter build apk --release
    echo.
    echo ✅ APK built successfully!
    echo 📱 APK location: build/app/outputs/flutter-apk/app-release.apk
) else (
    echo.
    echo 💡 To build APK later, run: flutter build apk --release
) 