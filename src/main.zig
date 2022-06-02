const std = @import("std");
const c = @import("c.zig");
const l = @import("level.zig");
const levels = @embedFile("levels.txt");

const WINDOW_WIDTH = 900;
const WINDOW_HEIGHT = 600;

pub fn main() anyerror!void {
    //allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) @panic("LEAK DETECTED");
    }
    const allocator = gpa.allocator();
    //SDL init
    if(c.SDL_Init(c.SDL_INIT_VIDEO)<0){
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    //window init
    const window = c.SDL_CreateWindow(
        "Zigoban",
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
    _ = c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND);
    //generate Level
    var reader = std.mem.tokenize(u8,levels,",;");
    var level = try l.Level.load(allocator, &reader);
    defer level.destroy();

    //main loop
    mainloop: while (true) {

        var move: ?l.Move = null;
        //events
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event) != 0) {
            switch (sdl_event.type) {
                c.SDL_QUIT => break :mainloop,
                c.SDL_KEYDOWN => {
                        switch (sdl_event.key.keysym.sym){
                            c.SDLK_w, c.SDLK_UP => move = .up,
                            c.SDLK_a, c.SDLK_LEFT => move = .left,
                            c.SDLK_s, c.SDLK_DOWN => move = .down,
                            c.SDLK_d, c.SDLK_RIGHT => move = .right,
                            c.SDLK_u => level.undo(),
                            c.SDLK_r => level.reset(),
                            else => {}
                        }
                    },
                else => {}
            }
        }

        //game logic
        if (level.solved()) {
            const load = l.Level.load(allocator, &reader) catch break :mainloop;
            level.destroy();
            level = load;
        }
        if (move!=null){
            try level.do(move.?);
        }

        //render
        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = c.SDL_RenderClear(renderer);
        
        level.render(renderer,WINDOW_WIDTH,WINDOW_HEIGHT);


        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(16);
    }
}

