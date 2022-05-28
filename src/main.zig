const std = @import("std");
const c = @import("c.zig");

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;

pub fn main() anyerror!void {
    //SDL init
    if(c.SDL_Init(c.SDL_INIT_VIDEO)<0){
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    //window init
    const window = c.SDL_CreateWindow(
        "Sokoban",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        0
    ) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);
    //renderer init
    const renderer = c.SDL_CreateRenderer(
        window,
        -1,
        c.SDL_RENDERER_ACCELERATED
    ) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    //main loop
    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                else => {},
            }
        }
        _ = c.SDL_SetRenderDrawColor(renderer, 0x12, 0x12, 0x12, 0xff);
        _ = c.SDL_RenderClear(renderer);
        c.SDL_RenderPresent(renderer);
    }
}

