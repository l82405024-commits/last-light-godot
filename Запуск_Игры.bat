@echo off
chcp 65001 > nul
echo Запуск игры "Последний Свет" на Godot 4.6...
start "" "C:\opencode\tools\Godot_v4.6-stable_win64.exe" --path "%~dp0."
