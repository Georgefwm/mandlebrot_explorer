@echo off

glslc shader.glsl.vert -o shader.spv.vert
if %errorlevel% neq 0 exit /b 1
echo Vertex shader compiled

glslc shader.glsl.frag -o shader.spv.frag
if %errorlevel% neq 0 exit /b 1
echo Fragment shader compiled

echo Compiling app...
odin build . -debug
if %errorlevel% neq 0 exit /b 1
echo App built

if "%~1" == "run" (
    mandlebrot_explorer.exe
)
