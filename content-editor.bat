@echo off
cd /d "%~dp0"
if exist ".tools\Godot.exe" (
  ".tools\Godot.exe" --path "%cd%" --script res://tools/content_editor/editor.gd
  exit /b
)
where godot.exe >nul 2>nul
if %errorlevel% equ 0 (
  godot.exe --path "%cd%" --script res://tools/content_editor/editor.gd
  exit /b
)
where godot4.exe >nul 2>nul
if %errorlevel% equ 0 (
  godot4.exe --path "%cd%" --script res://tools/content_editor/editor.gd
  exit /b
)
echo Godot 4 is required. Put Godot.exe in .tools or add it to PATH.
pause
