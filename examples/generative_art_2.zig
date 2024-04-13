const std = @import("std");
const math = std.math;
const jok = @import("jok");
const sdl = jok.sdl;
const j2d = jok.j2d;

pub const jok_window_size = jok.config.WindowSize{
    .custom = .{ .width = 1024, .height = 768 },
};

var path: j2d.Path = undefined;

pub fn init(_: jok.Context) !void {
    std.log.info("game init", .{});

    path = j2d.Path.begin();
}

pub fn event(ctx: jok.Context, e: sdl.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    _ = ctx;
}

pub fn draw(ctx: jok.Context) !void {
    ctx.clear(null);

    const statechange = math.sin(ctx.seconds()) * 0.2;
    const scale = ctx.getCanvasSize().y / 4;

    path.reset();
    var i: usize = 0;
    while (i < 360 * 4 + 1) : (i += 1) {
        var point = sdl.PointF{ .x = 0, .y = 0 };
        var j: usize = 0;
        while (j < 5) : (j += 1) {
            const angle = jok.utils.math.degreeToRadian(@as(f32, @floatFromInt(i)) / 4 * math.pow(f32, 3.0, @as(f32, @floatFromInt(j))));
            const off = math.pow(f32, 0.4 + statechange, @as(f32, @floatFromInt(j)));
            point.x += math.cos(angle) * off;
            point.y += math.sin(angle) * off;
        }
        try path.lineTo(point);
    }
    path.end(.stroke, .{ .closed = true });

    var transform = j2d.AffineTransform.init();
    transform.scale(.{ .x = scale, .y = scale });
    transform.translate(.{
        .x = ctx.getCanvasSize().x / 2,
        .y = ctx.getCanvasSize().y / 2,
    });

    j2d.begin(.{ .transform = transform });
    defer j2d.end();
    try j2d.path(path, .{});
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});

    path.deinit();
}
