# Mandlebrot Explorer
Mandlebrot rendering app that utilises a fragment shader for fast approximation.
Uses a simple escape time algorithm at higher zoom levels, and a perturbation theory based algorithm for zooming much deeper (switch with space bar).

## Key Binds
| Key    | Action                                       |
| :----- | :--------------------------------------------|
| Click  | Camera drag                                  |
| Scroll | Zoom in/out                                  |
| Space  | Toggle between simple and purturbation modes |
| C      | Toggle between color and greyscale modes     |
| P      | Output current position to console           |
| ESC    | Quit                                         |


## Build from source

#### Prerequisites
- Odin compiler
- Vulkan SDK (to compile shaders with glslc)

```shell
git clone https://github.com/Georgefwm/mandlebrot_explorer
```
```shell
cd mandlebrot_explorer
```
```shell
./build.bat
./mandlebrot_explorer.exe
```
or
```shell
./build.bat -run
```
