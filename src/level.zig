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
    right,

    fn opposite(self: Move) Move{
        return switch(self){
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }

    fn addToVector(self: Move,xy: @Vector(2,u8)) @Vector(2,u8){
        var v = xy;
        switch(self){
            .up => v[1] -%= 1,
            .down => v[1] +%= 1,
            .left => v[0] -%= 1,
            .right => v[0] +%= 1,
        }
        return v;
    }
};

const Tile = struct{
    floor: Floor,
    object: Object,

    fn color(self: *Tile) u32{
        switch (self.object){
            .none => {
                    switch (self.floor){
                        .none => return 0x121212ff,
                        .plate => return 0x44aa44ff,
                    }
                },
            .player => return 0x4F94CDff,
            .box => return 0x8B4513ff,
            .wall => return 0x666666ff
        }
    }

    fn isEqual(self: *Tile, other: *Tile) bool{
        return self.object == other.object and self.floor == other.floor;
    }


    fn pushable(self: *Tile) bool{
        return self.object==.player or self.object==.box;
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
            if (!self.tile[i].isEqual(&other.tile[i])) 
                return false;
        }
        return true;
    }

};

pub const Level = struct{
    sizeX: u8,
    sizeY: u8,
    state: *State,
    allocator: std.mem.Allocator,

    fn index(self: *Level, xy: @Vector(2,u8)) u16{
        return xy[0]+self.sizeX*@intCast(u16,xy[1]);
    }

    fn at(self: *Level, xy: @Vector(2,u8)) ?*Tile{
        if (xy[0]>=self.sizeX or xy[1]>=self.sizeY){
            return null;
        }
        return &self.state.tile[self.index(xy)];
    }

    fn isPushableAt(self: *Level, xy: @Vector(2,u8)) bool{
        return self.at(xy) != null and self.at(xy).?.pushable();
    }

    fn isObjectAt(self: *Level, xy: @Vector(2,u8), obj: Object) bool{
        return self.at(xy) != null and self.at(xy).?.object == obj;
    }

    pub fn load(allocator: std.mem.Allocator, reader: *std.mem.TokenIterator(u8)) !Level{
        const sizeX = try std.fmt.parseInt(u8, reader.next() orelse return error.ParseLevel, 10);
        const sizeY = try std.fmt.parseInt(u8, reader.next() orelse return error.ParseLevel, 10);
        const data = reader.next() orelse return error.ParseLevel;
        var state = try allocator.create(State);
        errdefer allocator.destroy(state);
        const size = sizeX*@intCast(u16,sizeY);
        state.tile = try allocator.alloc(Tile, size);
        errdefer allocator.free(state.tile);
        state.prev = null;
        var i: u16 = 0;
        for (data) |d|{
            switch (d){
                '.' =>{
                    state.tile[i].object=.none;
                    state.tile[i].floor=.none;
                },
                '_' =>{
                    state.tile[i].object=.none;
                    state.tile[i].floor=.plate;
                },
                'W' =>{
                    state.tile[i].object=.wall;
                    state.tile[i].floor=.none;
                },
                'B' =>{
                    state.tile[i].object=.box;
                    state.tile[i].floor=.none;
                },
                'P' =>{
                    state.tile[i].object=.player;
                    state.tile[i].floor=.none;
                },
                else =>{
                    i-%=1;
                }
            }
            i+%=1;
        }
        if (i!=size) return error.ParseLevel;
        return Level{
            .sizeX = sizeX,
            .sizeY = sizeY,
            .state = state,
            .allocator = allocator,
        };
    }

    pub fn destroy(self: *Level) void{
        self.state.destroy(self.allocator);
    }

    pub fn do(self: *Level, move: Move) !void {
        // create next state
        var next = try self.state.next(self.allocator);
        var xy = @Vector(2,u8){0,0};
        while (xy[0]<self.sizeX):(xy[0]+=1){
            xy[1] = 0;
            tileloop: while (xy[1]<self.sizeY):(xy[1]+=1){
                //find player
                if (!self.isObjectAt(xy,.player)) continue: tileloop;
                //check if player can move
                var dxy = xy;
                while (self.isPushableAt(dxy)){
                    dxy = move.addToVector(dxy);
                }
                if (!self.isObjectAt(dxy,.none)) continue: tileloop;
                //check if player gets pushed
                dxy = xy;
                while (self.isPushableAt(dxy)){
                    dxy = move.opposite().addToVector(dxy);
                    if (self.isObjectAt(dxy,.player)) continue: tileloop;
                }
                //find push start (pull)
                dxy = move.opposite().addToVector(xy);
                if (!self.isPushableAt(dxy)) dxy = xy;
                //push
                var last = Object.none;
                while (self.isPushableAt(dxy)){
                    next.tile[self.index(dxy)].object = last;
                    last = self.state.tile[self.index(dxy)].object; 
                    dxy = move.addToVector(dxy);                  
                }
                next.tile[self.index(dxy)].object = last;
            }
        }
        // only use the new state if something changed
        if (!self.state.isEqual(next)){
            self.state = next;
        }
        else{
            _ = next.undo(self.allocator);
        }
        return;
    }

    pub fn solved(self: *Level) bool{
        for (self.state.tile) |t|{
            if (t.floor==.plate and t.object!=.box) return false;
        }
        return true;
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

        var xy = @Vector(2,u8){0,0};
        while (xy[0]<self.sizeX):(xy[0]+=1){
            xy[1] = 0;
            while (xy[1]<self.sizeY):(xy[1]+=1){
                const r = c.SDL_Rect{
                    .x = @intCast(c_int,offsetX+size*xy[0]),
                    .y = @intCast(c_int,offsetY+size*xy[1]),
                    .w = @intCast(c_int,size),
                    .h = @intCast(c_int,size)
                };
                const color = self.at(xy).?.color();
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