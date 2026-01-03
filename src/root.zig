const std = @import("std");
const rl = @import("raylib");
const wp = @import("wallpaper.zig");
const constants = @import("constants.zig");

const SelectionMode = enum {
    cursor,
    keyboard,
};

pub fn createFiles(allocator: std.mem.Allocator) !void {
    const cachePath = try constants.getCacheDir(allocator);
    defer allocator.free(cachePath);
    try std.fs.cwd().makePath(cachePath);
}

pub fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try createFiles(allocator);

    const screen_width = constants.DEFAULT_WIDTH;
    const screen_height = constants.DEFAULT_HEIGHT;
    rl.initWindow(screen_width, screen_height, "Zpaper");
    defer rl.closeWindow();

    rl.setWindowState(.{
        .window_resizable = false,
    });

    rl.setTargetFPS(60);
    rl.setWindowMonitor(1);

    var wallpapers = try wp.getWallpapers(allocator);
    defer {
        for (wallpapers.items) |*wall| wall.deinit();
        wallpapers.deinit(allocator);
    }

    const cards_per_row = constants.DEFAULT_WIDTH / constants.THUMBNAIL_SIZE;
    // const rows = constants.DEFAULT_HEIGHT / constants..THUMBNAIL_SIZE;

    for (wallpapers.items, 0..) |*wall, i| {
        // load texture
        try wall.loadImageCached();
        try wall.loadTexture();

        // set position
        wall.x = @as(i32, @intCast(i % cards_per_row * constants.THUMBNAIL_SIZE));
        wall.y = @as(i32, @intCast(@divFloor(i, cards_per_row) * constants.THUMBNAIL_SIZE));
    }

    var selection: ?usize = null;

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.left)) {
            if (selection) |i| {
                selection = if (i > 0) i - 1 else 0;
            } else {
                selection = 0;
            }
        } else if (rl.isKeyPressed(.right)) {
            if (selection) |i| {
                selection = if (i < wallpapers.items.len - 1) i + 1 else selection;
            } else {
                selection = 0;
            }
        } else if (rl.isKeyPressed(.up)) {
            if (selection) |i| {
                selection = if (i >= cards_per_row) i - cards_per_row else 0;
            } else {
                selection = 0;
            }
        } else if (rl.isKeyPressed(.down)) {
            if (selection) |i| {
                selection = if (i < wallpapers.items.len - cards_per_row) i + cards_per_row else if (i % cards_per_row >= wallpapers.items.len % cards_per_row) wallpapers.items.len - 1 else selection;
            } else {
                selection = 0;
            }
        } else if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.space)) {
            if (selection) |s| {
                // try wallpapers.items[s].preview();
                try wallpapers.items[s].setAsWallpaper();
            }
        }

        // check mouse hover
        const mouse_delta = rl.getMouseDelta();
        if (mouse_delta.x != 0 or mouse_delta.y != 0) {
            selection = null;
            for (wallpapers.items, 0..) |wall, i| {
                const rec = rl.Rectangle{
                    .x = @as(f32, @floatFromInt(wall.x)),
                    .y = @as(f32, @floatFromInt(wall.y)),
                    .width = constants.THUMBNAIL_SIZE,
                    .height = constants.THUMBNAIL_SIZE,
                };
                if (rl.checkCollisionPointRec(rl.getMousePosition(), rec)) {
                    selection = i;
                }
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        for (wallpapers.items, 0..) |wall, i| {
            // const nameZ = try allocator.dupeZ(u8, std.fs.path.basename(path));
            // defer allocator.free(nameZ);

            if (i != selection) {
                wall.draw(false);
            }

            // rl.drawText(nameZ, 0, @as(i32, @intCast(i)) * 14, 12, .white);
        }

        if (selection) |i| {
            wallpapers.items[i].draw(true);
        }

        // Draw FPS counter
        var buffer: [50]u8 = undefined;
        const msg = try std.fmt.bufPrintZ(&buffer, "FPS: {d}", .{rl.getFPS()});
        rl.drawText(msg, screen_width - 48, screen_height - 14, 12, .white);
    }
}
