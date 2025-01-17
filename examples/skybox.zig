const std = @import("std");
const jok = @import("jok");
const sdl = jok.sdl;
const physfs = jok.physfs;
const imgui = jok.imgui;
const font = jok.font;
const zmath = jok.zmath;
const zmesh = jok.zmesh;
const j3d = jok.j3d;

var camera: j3d.Camera = undefined;
var cube: zmesh.Shape = undefined;
var tex: sdl.Texture = undefined;
var texcoords = [_][2]f32{
    .{ 0, 1 },
    .{ 0, 0 },
    .{ 1, 0 },
    .{ 1, 1 },
    .{ 1, 1 },
    .{ 0, 1 },
    .{ 0, 0 },
    .{ 1, 0 },
};
var skybox_textures: [6]sdl.Texture = undefined;
var skybox_tint_color: sdl.Color = sdl.Color.white;

pub fn init(ctx: jok.Context) !void {
    std.log.info("game init", .{});

    try physfs.mount("assets", "", true);

    camera = j3d.Camera.fromPositionAndTarget(
        .{
            //.orthographic = .{
            //    .width = 2 * ctx.getAspectRatio(),
            //    .height = 2,
            //    .near = 0.1,
            //    .far = 100,
            //},
            .perspective = .{
                .fov = std.math.pi / 4.0,
                .aspect_ratio = ctx.getAspectRatio(),
                .near = 0.1,
                .far = 100,
            },
        },
        [_]f32{ 0, 1, -2 },
        [_]f32{ 0, 0, 0 },
    );
    cube = zmesh.Shape.initCube();
    cube.computeNormals();
    cube.texcoords = texcoords[0..];
    tex = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/image5.jpg",
        .static,
        false,
    );

    skybox_textures[0] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/right.jpg",
        .static,
        true,
    );
    skybox_textures[1] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/left.jpg",
        .static,
        true,
    );
    skybox_textures[2] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/top.jpg",
        .static,
        true,
    );
    skybox_textures[3] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/bottom.jpg",
        .static,
        true,
    );
    skybox_textures[4] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/front.jpg",
        .static,
        true,
    );
    skybox_textures[5] = try jok.utils.gfx.createTextureFromFile(
        ctx,
        "images/skybox/back.jpg",
        .static,
        true,
    );
}

pub fn event(ctx: jok.Context, e: sdl.Event) !void {
    _ = ctx;
    _ = e;
}

pub fn update(ctx: jok.Context) !void {
    // camera movement
    const distance = ctx.deltaSeconds() * 2;
    if (ctx.isKeyPressed(.w)) {
        camera.moveBy(.forward, distance);
    }
    if (ctx.isKeyPressed(.s)) {
        camera.moveBy(.backward, distance);
    }
    if (ctx.isKeyPressed(.a)) {
        camera.moveBy(.left, distance);
    }
    if (ctx.isKeyPressed(.d)) {
        camera.moveBy(.right, distance);
    }
    if (ctx.isKeyPressed(.left)) {
        camera.rotateBy(0, -std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.right)) {
        camera.rotateBy(0, std.math.pi / 180.0);
    }
    if (ctx.isKeyPressed(.up)) {
        camera.rotateBy(std.math.pi / 180.0, 0);
    }
    if (ctx.isKeyPressed(.down)) {
        camera.rotateBy(-std.math.pi / 180.0, 0);
    }
}

pub fn draw(ctx: jok.Context) !void {
    ctx.clear(sdl.Color.rgb(77, 77, 77));

    if (imgui.begin("Tint Color", .{})) {
        var cs: [3]f32 = .{
            @as(f32, @floatFromInt(skybox_tint_color.r)) / 255,
            @as(f32, @floatFromInt(skybox_tint_color.g)) / 255,
            @as(f32, @floatFromInt(skybox_tint_color.b)) / 255,
        };
        if (imgui.colorEdit3("Tint Color", .{ .col = &cs })) {
            skybox_tint_color.r = @intFromFloat(cs[0] * 255);
            skybox_tint_color.g = @intFromFloat(cs[1] * 255);
            skybox_tint_color.b = @intFromFloat(cs[2] * 255);
        }
    }
    imgui.end();

    j3d.begin(.{ .camera = camera, .triangle_sort = .simple });
    defer j3d.end();
    try j3d.shape(
        cube,
        zmath.mul(
            zmath.translation(-0.5, -0.5, -0.5),
            zmath.mul(
                zmath.scaling(0.5, 0.5, 0.5),
                zmath.rotationY(ctx.seconds() * std.math.pi),
            ),
        ),
        null,
        .{ .texture = tex },
    );
    try j3d.skybox(skybox_textures, skybox_tint_color);

    font.debugDraw(
        ctx,
        .{ .x = 20, .y = 10 },
        "Press WSAD and up/down/left/right to move camera around the view",
        .{},
    );
    font.debugDraw(
        ctx,
        .{ .x = 20, .y = 28 },
        "Camera: pos({d:.3},{d:.3},{d:.3}) dir({d:.3},{d:.3},{d:.3})",
        .{
            // zig fmt: off
            camera.position[0],camera.position[1],camera.position[2],
            camera.dir[0],camera.dir[1],camera.dir[2],
        },
    );
}

pub fn quit(ctx: jok.Context) void {
    _ = ctx;
    std.log.info("game quit", .{});

    cube.deinit();
}
