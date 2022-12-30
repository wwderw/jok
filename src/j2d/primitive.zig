const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const sdl = @import("sdl");
const jok = @import("../jok.zig");
const imgui = jok.imgui;
const zmath = jok.zmath;

pub const BasicFillOption = struct {
    offset: ?sdl.PointF = null,
    rotate: f32 = 0,
    anchor: ?sdl.PointF = null,

    pub fn getMatrix(self: @This()) zmath.Mat {
        return getTransformMatrix(
            self.anchor orelse sdl.PointF{ .x = 0, .y = 0 },
            self.rotate,
            self.offset orelse sdl.PointF{ .x = 0, .y = 0 },
        );
    }
};

pub const BasicDrawOption = struct {
    usingnamespace BasicDrawOption;
    thickness: f32 = 1.0,
};

var draw_list: ?imgui.DrawList = null;

/// Create primitive renderer
pub fn init() void {
    draw_list = imgui.createDrawList();
}

/// Destroy primitive renderer
pub fn deinit() void {
    imgui.destroyDrawList(draw_list.?);
}

/// Clear batched vertex data
pub fn clear() void {
    draw_list.?.reset();
}

/// Render data
pub fn draw(rd: sdl.Renderer) !void {
    if (draw_list.?.getCmdBufferLength() <= 0) return;

    const fb_size = try rd.getOutputSize();
    const old_clip_rect = try rd.getClipRect();
    defer rd.setClipRect(old_clip_rect) catch unreachable;

    const commands = draw_list.?.getCmdBufferData()[0..@intCast(u32, draw_list.?.getCmdBufferLength())];
    const vs_ptr = draw_list.?.getVertexBufferData();
    const vs_count = draw_list.?.getVertexBufferLength();
    const is_ptr = draw_list.?.getIndexBufferData();
    for (commands) |cmd| {
        if (cmd.user_callback) |_| continue;

        // Apply clip rect
        var clip_rect: sdl.Rectangle = undefined;
        clip_rect.x = math.min(0, @intCast(c_int, cmd.clip_rect[0]));
        clip_rect.y = math.min(0, @intCast(c_int, cmd.clip_rect[1]));
        clip_rect.width = math.min(fb_size.width_pixels, @intCast(c_int, cmd.clip_rect[2] - cmd.clip_rect[0]));
        clip_rect.height = math.min(fb_size.height_pixels, @intCast(c_int, cmd.clip_rect[3] - cmd.clip_rect[1]));
        if (clip_rect.width <= 0 or clip_rect.height <= 0) continue;
        try rd.setClipRect(clip_rect);

        // Bind texture and draw
        const xy = @ptrToInt(vs_ptr + @intCast(usize, cmd.vtx_offset)) + @offsetOf(imgui.DrawVert, "pos");
        const uv = @ptrToInt(vs_ptr + @intCast(usize, cmd.vtx_offset)) + @offsetOf(imgui.DrawVert, "uv");
        const cs = @ptrToInt(vs_ptr + @intCast(usize, cmd.vtx_offset)) + @offsetOf(imgui.DrawVert, "color");
        const is = is_ptr + cmd.idx_offset;
        const tex = cmd.texture_id;
        _ = sdl.c.SDL_RenderGeometryRaw(
            rd.ptr,
            @ptrCast(?*sdl.c.SDL_Texture, tex),
            @intToPtr([*]f32, xy),
            @sizeOf(imgui.DrawVert),
            @intToPtr([*]f32, cs),
            @sizeOf(imgui.DrawVert),
            @intToPtr([*]f32, uv),
            @sizeOf(imgui.DrawVert),
            @intCast(c_int, vs_count) - @intCast(c_int, cmd.vtx_offset),
            @ptrCast([*]c_int, is),
            @intCast(c_int, cmd.elem_count),
            @sizeOf(imgui.DrawIdx),
        );
    }
}

pub fn pushClipRect(rect: sdl.RectangleF, intersect_with_current: bool) void {
    draw_list.?.pushClipRect(.{
        .pmin = .{ rect.x, rect.y },
        .pmax = .{ rect.x + rect.width, rect.y + rect.height },
        .intersect_with_current = intersect_with_current,
    });
}

pub fn popClipRect() void {
    draw_list.?.popClipRect();
}

pub fn pushTexture(tex: sdl.Texture) void {
    draw_list.?.pushTextureId(tex.ptr);
}

pub fn popTexture() void {
    draw_list.?.popTextureId();
}

pub fn addLine(_p1: sdl.PointF, _p2: sdl.PointF, color: sdl.Color, opt: BasicDrawOption) void {
    const m = opt.getMatrix();
    const p1 = transformPoint(_p1, m);
    const p2 = transformPoint(_p2, m);
    draw_list.?.addLine(.{
        .p1 = .{ p1.x, p1.y },
        .p2 = .{ p2.x, p2.y },
        .col = convertColor(color),
        .thickness = opt.thickness,
    });
}

pub const AddRect = struct {
    usingnamespace BasicDrawOption;
    rounding: f32 = 0,
};
pub fn addRect(rect: sdl.RectangleF, color: sdl.Color, opt: AddRect) void {
    const m = opt.getMatrix();
    const _p1 = sdl.PointF{
        .x = rect.x,
        .y = rect.y,
    };
    const _p2 = sdl.PointF{
        .x = rect.x + rect.width,
        .y = rect.y + rect.height,
    };
    const p1 = transformPoint(_p1, m);
    const p2 = transformPoint(_p2, m);
    draw_list.?.addRect(.{
        .pmin = .{ p1.x, p1.y },
        .pmax = .{ p2.x, p2.y },
        .col = convertColor(color),
        .rounding = opt.rounding,
        .thickness = opt.thickness,
    });
}

pub const FillRect = struct {
    usingnamespace BasicFillOption;
    rounding: f32 = 0,
};
pub fn addRectFilled(rect: sdl.RectangleF, color: sdl.Color, opt: FillRect) void {
    const m = opt.getMatrix();
    const _p1 = sdl.PointF{
        .x = rect.x,
        .y = rect.y,
    };
    const _p2 = sdl.PointF{
        .x = rect.x + rect.width,
        .y = rect.y + rect.height,
    };
    const p1 = transformPoint(_p1, m);
    const p2 = transformPoint(_p2, m);
    draw_list.addRectFilled(.{
        .pmin = .{ p1.x, p1.y },
        .pmax = .{ p2.x, p2.y },
        .col = convertColor(color),
        .rounding = opt.rounding,
    });
}

pub fn addRectFilledMultiColor(
    rect: sdl.RectangleF,
    color_top_left: sdl.Color,
    color_top_right: sdl.Color,
    color_bottom_right: sdl.Color,
    color_bottom_left: sdl.Color,
    opt: FillRect,
) void {
    const m = opt.getMatrix();
    const _p1 = sdl.PointF{
        .x = rect.x,
        .y = rect.y,
    };
    const _p2 = sdl.PointF{
        .x = rect.x + rect.width,
        .y = rect.y + rect.height,
    };
    const p1 = transformPoint(_p1, m);
    const p2 = transformPoint(_p2, m);
    draw_list.addRectFilled(.{
        .pmin = .{ p1.x, p1.y },
        .pmax = .{ p2.x, p2.y },
        .col_upr_left = convertColor(color_top_left),
        .col_upr_right = convertColor(color_top_right),
        .col_bot_right = convertColor(color_bottom_right),
        .col_bot_left = convertColor(color_bottom_left),
        .rounding = opt.rounding,
    });
}

// Calculate transform matrix
inline fn getTransformMatrix(anchor: sdl.PointF, rotate: f32, offset: sdl.PointF) zmath.Mat {
    const translate1_m = zmath.translation(-anchor.x, -anchor.y, 0);
    const rotate_m = zmath.rotationZ(rotate * math.pi / 180);
    const translate2_m = zmath.translation(anchor.x, anchor.y, 0);
    const translate3_m = zmath.translation(offset.x, offset.y, 0);
    return zmath.mul(zmath.mul(zmath.mul(translate1_m, rotate_m), translate2_m), translate3_m);
}

// Transform coordinate
inline fn transformPoint(pos: sdl.PointF, trs: zmath.Mat) sdl.PointF {
    const v = zmath.f32x4(pos.x, pos.y, 0, 1);
    const tv = zmath.mul(v, trs);
    return .{ .x = tv[0], .y = tv[1] };
}

// Convert RGBA color
inline fn convertColor(color: sdl.Color) u32 {
    return @intCast(u32, color.r) |
        (@intCast(u32, color.g) << 8) |
        (@intCast(u32, color.b) << 16) |
        (@intCast(u32, color.a) << 24);
}
