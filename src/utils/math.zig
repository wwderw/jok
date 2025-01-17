const std = @import("std");
const jok = @import("../jok.zig");
const sdl = jok.sdl;
const assert = std.debug.assert;
const math = std.math;
const zmath = jok.zmath;

/// Linearly map `v` from [from, to] to [map_from, map_to]
pub inline fn linearMap(_v: f32, from: f32, to: f32, map_from: f32, map_to: f32) f32 {
    const v = if (from < to) math.clamp(_v, from, to) else math.clamp(_v, to, from);
    return map_from + (map_to - map_from) * (v - from) / (to - from);
}

/// Smoothly map from [from, to] to [map_from, map_to], checkout link https://en.wikipedia.org/wiki/Smoothstep
pub inline fn smoothMap(_v: f32, from: f32, to: f32, map_from: f32, map_to: f32) f32 {
    const v = if (from < to) math.clamp(_v, from, to) else math.clamp(_v, to, from);
    var step = (v - from) / (to - from);
    step = step * step * (3 - 2 * step); // smooth to [0, 1], using equation: 3x^2 - 2x^3
    return map_from + (map_to - map_from) * step;
}

/// Convert radian to degree
pub inline fn radianToDegree(r: f32) f32 {
    return r * 180.0 / math.pi;
}

/// Convert degree to radian
pub inline fn degreeToRadian(d: f32) f32 {
    return d * math.pi / 180.0;
}

/// Get min and max of 3 value
pub inline fn minAndMax(_x: anytype, _y: anytype, _z: anytype) std.meta.Tuple(&[_]type{
    @TypeOf(_x, _y, _z),
    @TypeOf(_x, _y, _z),
}) {
    var x = _x;
    var y = _y;
    var z = _z;
    if (x > y) std.mem.swap(@TypeOf(_x, _y, _z), &x, &y);
    if (x > z) std.mem.swap(@TypeOf(_x, _y, _z), &x, &z);
    if (y > z) std.mem.swap(@TypeOf(_x, _y, _z), &y, &z);
    return .{ x, z };
}

/// Transform coordinate between isometric space and screen space
pub const IsometricTransform = struct {
    tile_width: f32,
    iso_to_screen: zmath.Mat,
    screen_to_iso: zmath.Mat,

    pub const IsometricOption = struct {
        xy_offset: sdl.PointF = .{ .x = 0, .y = 0 },
        scale: f32 = 1.0,
    };
    pub fn init(tile_size: sdl.Size, opt: IsometricOption) @This() {
        assert(tile_size.width > 0 and tile_size.height > 0);
        const w = @as(f32, @floatFromInt(tile_size.width)) * opt.scale;
        const h = @as(f32, @floatFromInt(tile_size.height)) * opt.scale;
        const mat = zmath.loadMat(&.{
            0.5 * w,                   0.5 * h,         0, 0,
            -0.5 * w,                  0.5 * h,         0, 0,
            0,                         0,               1, 0,
            opt.xy_offset.x - 0.5 * w, opt.xy_offset.y, 0, 1,
        });
        return .{
            .tile_width = w,
            .iso_to_screen = mat,
            .screen_to_iso = zmath.inverse(mat),
        };
    }

    pub fn transformToScreen(self: @This(), p: sdl.PointF, zoffset: f32) sdl.PointF {
        const v = zmath.mul(zmath.f32x4(p.x, p.y, 0, 1), self.iso_to_screen);
        return .{ .x = v[0], .y = v[1] - zoffset };
    }

    pub fn transformToIso(self: @This(), p: sdl.PointF) sdl.PointF {
        const v = zmath.mul(
            zmath.f32x4(p.x - self.tile_width * 0.5, p.y, 0, 1),
            self.screen_to_iso,
        );
        return .{ .x = v[0], .y = v[1] };
    }
};
