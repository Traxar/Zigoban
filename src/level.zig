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

pub const Level = struct{
    sizeX: u8,
    sizeY: u8,
    tile: []Tile,
    prev: ?*Level=null,


    fn at(self: *Level, x: u8, y: u8) ?*Tile{
        if (x<0 or y<0 or x>=self.sizeX or y>=self.sizeY){
            return null;
        }
        return &self.tile[x+self.sizeX*y];
    }

    pub fn generate(allocator: std.mem.Allocator, sizeX: u8, sizeY: u8) !Level{
        var tile = try allocator.alloc(Tile, sizeX*@intCast(u16,sizeY));
        for (tile) |_,i|{
            if (i%5==0){
                tile[i].object = .wall;
                tile[i].floor = .none;
            }
            else{
                tile[i].object = .none;
                tile[i].floor = .none;
            }
        }
        tile[0].object = .player;
        return Level{
            .sizeX = sizeX,
            .sizeY = sizeY,
            .tile = tile
        };
    }

    pub fn destroy(self: *Level, allocator: std.mem.Allocator) void{
        allocator.free(self.tile);
    }

    // pub fn do(self: *Level, move: Move) *Level{
    //     return self;        
    // }

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