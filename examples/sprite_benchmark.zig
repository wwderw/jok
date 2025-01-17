const std = @import("std");
const jok = @import("jok");
const sdl = jok.sdl;
const physfs = jok.physfs;
const j2d = jok.j2d;

pub const jok_fps_limit: jok.config.FpsLimit = .none;

const Actor = struct {
    sprite: j2d.Sprite,
    pos: sdl.PointF,
    velocity: sdl.PointF,
};

const names = [_][]const u8{
    "ogre",
    "quicksilver_dragon",
    "rock_troll",
    "rock_troll_monk_ghost",
    "sphinx",
};

var sheet: *j2d.SpriteSheet = undefined;
var characters: std.ArrayList(Actor) = undefined;
var rand_gen: std.Random.DefaultPrng = undefined;
var delta_tick: f32 = 0;

pub fn init(ctx: jok.Context) !void {
    std.log.info("game init", .{});

    try physfs.mount("assets", "/", true);

    const csz = ctx.getCanvasSize();

    // create sprite sheet
    sheet = try j2d.SpriteSheet.fromPicturesInDir(
        ctx,
        "images",
        @intFromFloat(csz.x),
        @intFromFloat(csz.y),
        .{},
    );
    characters = try std.ArrayList(Actor).initCapacity(
        ctx.allocator(),
        1000000,
    );
    rand_gen = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
}

pub fn event(ctx: jok.Context, e: sdl.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    const mouse = ctx.getMouseState();
    if (mouse.buttons.getPressed(.left)) {
        var rd = rand_gen.random();
        const pos = sdl.PointF{
            .x = @floatFromInt(mouse.x),
            .y = @floatFromInt(mouse.y),
        };
        var i: u32 = 0;
        while (i < 10) : (i += 1) {
            const angle = rd.float(f32) * 2 * std.math.pi;
            const select = rd.intRangeLessThan(u32, 0, names.len);
            try characters.append(.{
                .sprite = sheet.getSpriteByName(names[select]).?,
                .pos = pos,
                .velocity = .{
                    .x = 300 * @cos(angle),
                    .y = 300 * @sin(angle),
                },
            });
        }
    }

    delta_tick = (delta_tick + ctx.deltaSeconds()) / 2;
    const size = ctx.getCanvasSize();
    for (characters.items) |*c| {
        const curpos = c.pos;
        if (curpos.x < 0)
            c.velocity.x = @abs(c.velocity.x);
        if (curpos.x + c.sprite.width > size.x)
            c.velocity.x = -@abs(c.velocity.x);
        if (curpos.y < 0)
            c.velocity.y = @abs(c.velocity.y);
        if (curpos.y + c.sprite.height > size.y)
            c.velocity.y = -@abs(c.velocity.y);
        c.pos.x += c.velocity.x * ctx.deltaSeconds();
        c.pos.y += c.velocity.y * ctx.deltaSeconds();
    }
}

pub fn draw(ctx: jok.Context) !void {
    ctx.clear(sdl.Color.rgb(77, 77, 77));
    ctx.displayStats(.{});

    j2d.begin(.{});
    defer j2d.end();
    for (characters.items) |c| {
        try j2d.sprite(c.sprite, .{
            .pos = c.pos,
        });
    }
    try j2d.text(
        .{
            .atlas = try jok.font.DebugFont.getAtlas(ctx, 16),
            .pos = .{ .x = 0, .y = 0 },
        },
        "# of sprites: {d}",
        .{characters.items.len},
    );
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});
    sheet.destroy();
    characters.deinit();
}
