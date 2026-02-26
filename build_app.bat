@echo off
echo IVSP Subtitle Search - Build Script
echo ----------------------------------
echo 1. Initializing Flutter project...
call flutter create .
if %errorlevel% neq 0 (
    echo [X] 'flutter' buyrug'i topilmadi. Iltimos, Flutter SDK o'rnatilganiga ishonch hosil qiling.
    pause
    exit /b %errorlevel%
)

echo 2. Getting dependencies...
call flutter pub get

echo 3. Building APK (Debug)...
call flutter build apk --debug

if %errorlevel% eq 0 (
    echo [OK] Build muvaffaqiyatli yakunlandi! APK fayli: build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo [X] Buildda xatolik yuz berdi.
)
pause
