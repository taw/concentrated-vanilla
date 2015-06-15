@echo off
cd ..\..
IF EXIST kingdoms.exe (start kingdoms.exe @%0\..\concentrated_vanilla.cfg) ELSE (start medieval2.exe @%0\..\concentrated_vanilla.cfg) 