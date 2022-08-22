const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const builtin = @import("builtin");
const sdl = @import("sdl");
const jok = @import("jok");
const imgui = jok.deps.imgui;
const gfx = jok.gfx.@"2d";
const primitive = gfx.primitive;

pub const jok_window_resizable = true;

const PrimitiveType = enum(c_int) {
    etriangle,
    square,
    circle,
    arc,
    line,
};

var primtype: PrimitiveType = .etriangle;
var color: [4]f32 = .{ 1.0, 1.0, 1.0, 0.5 };
var size: f32 = 15;
var thickness: f32 = 0;
var rotate_angle: f32 = 0;
var rotate_anchor: [2]f32 = .{ 500, 500 };

pub fn init(ctx: *jok.Context) anyerror!void {
    std.log.info("game init", .{});

    try imgui.init(ctx);
    try primitive.init(ctx);
    try ctx.renderer.setColorRGB(77, 77, 77);
    try ctx.renderer.setDrawBlendMode(.blend);
}

pub fn loop(ctx: *jok.Context) anyerror!void {
    while (ctx.pollEvent()) |e| {
        _ = imgui.processEvent(e);

        switch (e) {
            .key_up => |key| {
                switch (key.scancode) {
                    .escape => ctx.kill(),
                    else => {},
                }
            },
            .quit => ctx.kill(),
            else => {},
        }
    }

    try ctx.renderer.clear();

    imgui.beginFrame();
    if (imgui.begin("Control Panel", null, null)) {
        var selection: *c_int = @ptrCast(*c_int, &primtype);
        _ = imgui.radioButton_IntPtr("etriangle", selection, 0);
        _ = imgui.radioButton_IntPtr("square", selection, 1);
        _ = imgui.radioButton_IntPtr("circle", selection, 2);
        _ = imgui.radioButton_IntPtr("arc", selection, 3);
        _ = imgui.radioButton_IntPtr("line", selection, 4);
        imgui.separator();
        _ = imgui.colorEdit4("color", &color, null);
        _ = imgui.dragFloat("size", &size, .{ .v_max = 1000 });
        _ = imgui.dragFloat("thickness", &thickness, .{ .v_max = 100 });
        _ = imgui.dragFloat("rotate_angle", &rotate_angle, .{});
        _ = imgui.dragFloat2("rotate_anchor", &rotate_anchor, .{});
    }
    imgui.end();
    imgui.endFrame();

    var ms = ctx.getMouseState();
    const draw_pos = sdl.PointF{ .x = @intToFloat(f32, ms.x), .y = @intToFloat(f32, ms.y) };
    const anchor_pos = sdl.PointF{ .x = rotate_anchor[0], .y = rotate_anchor[1] };
    const common_draw_opt = primitive.CommonDrawOption{
        .thickness = thickness,
        .rotate_degree = rotate_angle,
        .anchor_pos = anchor_pos,
        .color = .{
            .r = @floatToInt(u8, color[0] * 255),
            .g = @floatToInt(u8, color[1] * 255),
            .b = @floatToInt(u8, color[2] * 255),
            .a = @floatToInt(u8, color[3] * 255),
        },
    };
    primitive.clear();
    switch (primtype) {
        .etriangle => {
            try primitive.drawEquilateralTriangle(draw_pos, size, common_draw_opt);
        },
        .square => {
            try primitive.drawSquare(draw_pos, size, .{ .common = common_draw_opt, .round = size / 2 });
        },
        .circle => {
            try primitive.drawCircle(draw_pos, size, .{ .common = common_draw_opt });
        },
        .arc => {
            try primitive.drawArc(draw_pos, size, math.pi / 4.0, math.pi, .{ .common = common_draw_opt });
        },
        .line => {
            try primitive.drawLine(
                .{ .x = draw_pos.x - size, .y = draw_pos.y - size },
                .{ .x = draw_pos.x + size, .y = draw_pos.y + size },
                common_draw_opt,
            );
        },
    }
    try primitive.drawCircle(
        .{ .x = rotate_anchor[0], .y = rotate_anchor[1] },
        3,
        .{ .common = .{ .color = sdl.Color.cyan } },
    );
    try primitive.flush();
}

pub fn quit(ctx: *jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});

    imgui.deinit();
    primitive.deinit();
}
