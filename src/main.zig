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
        if (gpa.deinit() == .leak) @panic("LEAK DETECTED");
    }
    const allocator = gpa.allocator();
    //SDL init
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    //window init
    const window = c.SDL_CreateWindow("Zigoban", WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);
    //renderer init
    const renderer = c.SDL_CreateRenderer(window, null) orelse {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);
    _ = c.SDL_SetRenderDrawBlendMode(renderer, c.SDL_BLENDMODE_BLEND);
    //generate Level
    var reader = std.mem.tokenizeAny(u8, levels, ",;");
    var level = try l.Level.load(allocator, &reader);
    defer level.destroy();

    //main loop
    mainloop: while (true) {
        var move: ?l.Move = null;
        //events
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event)) {
            switch (sdl_event.type) {
                c.SDL_EVENT_QUIT => break :mainloop,
                c.SDL_EVENT_KEY_DOWN => {
                    switch (sdl_event.key.key) {
                        c.SDLK_W, c.SDLK_UP => move = .up,
                        c.SDLK_A, c.SDLK_LEFT => move = .left,
                        c.SDLK_S, c.SDLK_DOWN => move = .down,
                        c.SDLK_D, c.SDLK_RIGHT => move = .right,
                        c.SDLK_U => level.undo(),
                        c.SDLK_R => level.reset(),
                        else => {},
                    }
                },
                else => {},
            }
        }

        //game logic
        if (level.solved()) {
            const load = l.Level.load(allocator, &reader) catch break :mainloop;
            level.destroy();
            level = load;
        }
        if (move != null) {
            try level.do(move.?);
        }

        //render
        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = c.SDL_RenderClear(renderer);

        level.render(renderer, WINDOW_WIDTH, WINDOW_HEIGHT);

        _ = c.SDL_RenderPresent(renderer);
        c.SDL_Delay(16);
    }
}
