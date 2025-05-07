//
// Mandlebrot Explorer by George McLachlan.
//
// Simple and perturbation based mandlebrot renderer using a fragment shader.
//
// Keybinds:
// Click  -> Camera drag.
// Scroll -> Zoom in/out.
// Space  -> Toggle between simple and purturbation modes.
// C      -> Toggle between color and greyscale.
// P      -> Output current position to console.
// ESC    -> Quit.
//
// TODO:
// Fix camera drag at very low zoom levels (might not be possible).
// Add ability to output current view as image.
// Add DearImGui UIs for viewing/entering values.
// Do rendering optimisation pass.
// Add more descriptive comments?

package main

import "core:log"
import "core:fmt"
import math "core:math/linalg"
import sdl "vendor:sdl3"

vert_shader_code := #load("shader.spv.vert")
frag_shader_code := #load("shader.spv.frag")

WINDOW_TEXT: cstring = "Mandelbrot Explorer"

INITIAL_WINDOW_WIDTH:  i32 = 1920
INITIAL_WINDOW_HEIGHT: i32 = 1200
MAX_ITERATIONS:        i32 = 4096

CAMERA_MOVE_SPEED: f32 = 0.1
CAMERA_ZOOM_SPEED: f32 = 0.1

// Numbers we change to explore the fractal.
current_window_size: [2]i32 = { INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT }
current_zoom_center: [2]f32 = { -.74498851, 0.1859982 }  // (-1.5, -1) - (1, 1) seems to be a good range.
current_zoom_size:      f32 = 1.5e-6
desired_zoom_size:      f32 = 1.5e-6
use_perturbation:       i32 = 0
use_greyscale:          i32 = 0

camera_drag_active: bool = false

main :: proc() {
    context.logger = log.create_console_logger() 
    default_context := context

    sdl.SetHint(sdl.HINT_APP_NAME, WINDOW_TEXT)

    when ODIN_DEBUG {
        sdl.SetLogPriorities(.VERBOSE)
    }

    result := sdl.Init({.VIDEO})
    assert(result)

    window := sdl.CreateWindow(WINDOW_TEXT, INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT, {})
    assert(window != nil)

    device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
    assert(device != nil)

    result = sdl.ClaimWindowForGPUDevice(device, window)
    assert(result)

    vert_shader := sdl.CreateGPUShader(device, {
        code_size = len(vert_shader_code),
        code = raw_data(vert_shader_code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = .VERTEX,
        num_uniform_buffers = 0,
    })

    frag_shader := sdl.CreateGPUShader(device, {
        code_size = len(frag_shader_code),
        code = raw_data(frag_shader_code),
        entrypoint = "main",
        format = {.SPIRV},
        stage = .FRAGMENT,
        num_uniform_buffers = 1,
    })

    pipeline := sdl.CreateGPUGraphicsPipeline(device, {
        vertex_shader   = vert_shader,
        fragment_shader = frag_shader,
        primitive_type  = .TRIANGLELIST,
        target_info = {
            num_color_targets = 1,
            color_target_descriptions = &(sdl.GPUColorTargetDescription {
                format = sdl.GetGPUSwapchainTextureFormat(device, window)
            }),
        },
    })

    // Can release shaders now as they are already loaded into the pipeline.
    sdl.ReleaseGPUShader(device, vert_shader)
    sdl.ReleaseGPUShader(device, frag_shader)

    UBO :: struct #max_field_align(16) {
        resolution:    [2]i32,
        zoom_center:   [2]f32,
        zoom_size:        f32,
        max_iterations:   i32,
        use_perturbation: i32, 
        use_greyscale:    i32,
    }

    main_loop: for {
        // Events
        event: sdl.Event

        for sdl.PollEvent(&event) {
            #partial switch event.type {
                case .QUIT:
                    break main_loop
                case .KEY_DOWN:
                    if event.key.scancode == .ESCAPE do break main_loop
                    if event.key.scancode == .P {
                        fmt.println("Current position: ", current_zoom_center.x, current_zoom_center.y)
                    }
                    if event.key.scancode == .SPACE {
                        use_perturbation = use_perturbation == 1 ? 0 : 1
                    }
                    if event.key.scancode == .C {
                        use_greyscale = use_greyscale == 1 ? 0 : 1
                    }
                case .MOUSE_BUTTON_DOWN:
                    if event.button.button == sdl.BUTTON_LEFT {
                        camera_drag_active = true
                    }
                case .MOUSE_BUTTON_UP:
                    if event.button.button == sdl.BUTTON_LEFT {
                        camera_drag_active = false
                    }
                case .MOUSE_WHEEL:
                    desired_zoom_size = 
                        clamp(desired_zoom_size + event.wheel.y * CAMERA_ZOOM_SPEED * desired_zoom_size, 0, 1.5)
            }
        }

        // Updates
        sdl.GetWindowSize(window, &current_window_size.x, &current_window_size.y)
        handle_updates()

        // Render
        cmd_buffer := sdl.AcquireGPUCommandBuffer(device)
        swapchain_texture: ^sdl.GPUTexture

        result = sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window, &swapchain_texture, nil, nil)
        assert(result)

        ubo := UBO { 
            resolution       = current_window_size,
            zoom_center      = current_zoom_center,
            zoom_size        = current_zoom_size,
            max_iterations   = MAX_ITERATIONS,
            use_perturbation = use_perturbation,
            use_greyscale    = use_greyscale,
        }

        // Swapchain texture is null while window is minimised. 
        if (swapchain_texture != nil) {
            color_target := sdl.GPUColorTargetInfo {
                texture = swapchain_texture,
                load_op = .CLEAR,
                clear_color = { 0.2, 0.2, 0.2, 1.0 },
                store_op = .STORE
            }
            
            render_pass := sdl.BeginGPURenderPass(cmd_buffer, &color_target, 1, nil)

            sdl.BindGPUGraphicsPipeline(render_pass, pipeline)

            // sdl.PushGPUVertexUniformData(cmd_buffer, 0, &ubo, size_of(ubo))
            sdl.PushGPUFragmentUniformData(cmd_buffer, 0, &ubo, size_of(ubo))

            sdl.DrawGPUPrimitives(render_pass, 6, 1, 0, 0)

            sdl.EndGPURenderPass(render_pass)
        }

        result = sdl.SubmitGPUCommandBuffer(cmd_buffer)
        assert(result)
    }

}

// Updates 'camera' position/zoom.
handle_updates :: proc() {
    // Zoom
    zoom_delta: f32 = 0
    zoom_delta += desired_zoom_size - current_zoom_size
    current_zoom_size += zoom_delta

    movement_delta: [2]f32 = { 0.0, 0.0 }

    if camera_drag_active {
        _ = sdl.GetRelativeMouseState(&movement_delta.x, &movement_delta.y)
    }
    else {
        // Function has to be called every frame, even if we don't use the values.
        // Flushes changes on call.
        _ = sdl.GetRelativeMouseState(nil, nil)
    }
    
    // Normalise mouse movement (in line with shader coords).
    movement_delta.x = (movement_delta.x / cast(f32)current_window_size.x) * (2 * current_zoom_size)
    movement_delta.y = (movement_delta.y / cast(f32)current_window_size.y) * (2 * current_zoom_size)

    current_zoom_center -= movement_delta

    current_zoom_center.x = clamp(current_zoom_center.x, -2, 1.5)
    current_zoom_center.y = clamp(current_zoom_center.y, -1.5, 1.5)
}
