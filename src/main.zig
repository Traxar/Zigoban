const std = @import("std");
const c = @import("c.zig");

const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;



var x: u3 = 1;
var y: u3 = 1;

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
        //events
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => {
                        switch (sdl_event.key.keysym.sym){
                            c.SDLK_w => y -|= 1,
                            c.SDLK_a => x -|= 1,
                            c.SDLK_s => y +|= 1,
                            c.SDLK_d => x +|= 1,
                            else => {}
                        }
                    },
                else => {}
            }
        }
        //game logic

        //render
        _ = c.SDL_SetRenderDrawColor(renderer, 0x12, 0x12, 0x12, 0xff);
        _ = c.SDL_RenderClear(renderer);


        var rect = c.SDL_Rect{ .x = 50*@intCast(c_int,x), .y = 50*@intCast(c_int,y), .w = 50, .h = 50 };
        _ = c.SDL_SetRenderDrawColor(renderer, 0xaa, 0xaa, 0xaa, 0xff);
        _ = c.SDL_RenderFillRect(renderer, &rect);

        c.SDL_RenderPresent(renderer);
    }
}

