const std = @import("std");
const c = @import("c.zig");

const Floor = enum{
    none,
    plate,
};

const Object = enum{
    none,
    player,
    box,
    wall,
};

pub const Move = enum{
    up,
    down,
    left,
    right
};

const Tile = struct{
    floor: Floor,
    object: Object,

    fn color(self: *Tile) u32{
        switch (self.object){
            .none => {
                    switch (self.floor){
                        .none => return 0x121212ff,
                        .plate => return 0x32CD32ff,
                    }
                },
            .player => return 0x4F94CDff,
            .box => return 0x8B4513ff,
            .wall => return 0x666666ff
        }
    }
};

const State = struct{
    tile: []Tile,
    prev: ?*State=null,

    fn next(self: *State, allocator: std.mem.Allocator) !*State{
        var state = try allocator.create(State);
        state.tile = try allocator.alloc(Tile,self.tile.len);
        state.prev = self;
        for (state.tile) |_,i|{
            state.tile[i]=self.tile[i];
        }
        return state;
    }

    fn undo(self: *State, allocator: std.mem.Allocator) *State{
        if (self.prev == null)
            return self;
        allocator.free(self.tile);
        defer allocator.destroy(self);
        return self.prev.?;
    }

    fn reset(self: *State, allocator: std.mem.Allocator) *State{
        var ptr = self;
        while (ptr.prev != null){
            ptr = ptr.undo(allocator);
        }
        return ptr;
    }

    fn destroy(self: *State, allocator: std.mem.Allocator) void{
        var ptr = self.reset(allocator);
        allocator.free(ptr.tile);
        allocator.destroy(ptr);
    }

    fn isEqual(self: *State, other: *State) bool{
        //if (self.tile.len!=other.tile.len) return false;
        for (self.tile) |_,i|{
            if (self.tile[i]!=other.tile[i]) return false;
        }
        return true;
    }

};

pub const Level = struct{
    sizeX: u8,
    sizeY: u8,
    state: *State,
    allocator: std.mem.Allocator,


    fn at(self: *Level, x: u8, y: u8) ?*Tile{
        if (x<0 or y<0 or x>=self.sizeX or y>=self.sizeY){
            return null;
        }
        return &self.state.tile[x+self.sizeX*y];
    }

    pub fn generate(allocator: std.mem.Allocator, sizeX: u8, sizeY: u8) !Level{
        var state = try allocator.create(State);
        state.tile = try allocator.alloc(Tile, sizeX*@intCast(u16,sizeY));
        state.prev = null;
        for (state.tile) |_,i|{
            if (i%5==0){
                state.tile[i].object = .wall;
                state.tile[i].floor = .none;
            }
            else{
                state.tile[i].object = .none;
                state.tile[i].floor = .none;
            }
        }
        state.tile[0].object = .player;
        return Level{
            .sizeX = sizeX,
            .sizeY = sizeY,
            .state = state,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Level) void{
        self.state.destroy(self.allocator);
        //self.allocator.free(self.state.tile);
    }

    pub fn do(self: *Level, move: Move) !void {
        var x: u8 = 0;
        while (x<self.sizeX):(x+=1){
            var y: u8 = 0;
            while (y<self.sizeY):(y+=1){
                if (self.at(x,y).?.object == .player){
                    const dx:u8 = switch (move){
                        .left => x-|1,
                        .right => x+|1,
                        else => x
                    };
                    const dy:u8 = switch (move){
                        .up => y-|1,
                        .down => y+|1,
                        else => y
                    };
                    if (self.at(dx,dy)!=null and self.at(dx,dy).?.object!=.wall){
                        self.state = try self.state.next(self.allocator);
                        self.at(x,y).?.object = .none;
                        self.at(dx,dy).?.object = .player;
                    }
                    return;
                }
            }
        }
    }

    pub fn undo(self: *Level) void {
        self.state = self.state.undo(self.allocator);
    }

    pub fn reset(self: *Level) void {
        self.state = self.state.reset(self.allocator);
    }

    pub fn render(self: *Level,renderer: *c.SDL_Renderer, width: u32, height: u32) void {
        const size = @minimum(
            @divFloor(width,self.sizeX),
            @divFloor(height,self.sizeY),
        );
        const offsetX = @divFloor(width - size*self.sizeX,2);
        const offsetY = @divFloor(height - size*self.sizeY,2);

        var x: u8 = 0;
        while (x<self.sizeX):(x+=1){
            var y: u8 = 0;
            while (y<self.sizeY):(y+=1){
                const r = c.SDL_Rect{
                    .x = @intCast(c_int,offsetX+size*x),
                    .y = @intCast(c_int,offsetY+size*y),
                    .w = @intCast(c_int,size),
                    .h = @intCast(c_int,size)
                };
                const color = self.at(x,y).?.color();
                _ = c.SDL_SetRenderDrawColor(
                    renderer,
                    @truncate(u8,color >> 24),
                    @truncate(u8,color >> 16),
                    @truncate(u8,color >> 8),
                    @truncate(u8,color)
                );
                _ = c.SDL_RenderFillRect(renderer, &r);
            }
        }
    }

};