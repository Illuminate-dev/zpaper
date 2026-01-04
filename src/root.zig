const std = @import("std");
const rl = @import("raylib");
const wp = @import("wallpaper.zig");
const constants = @import("constants.zig");

const State = union(enum) {
    Preview: usize,
    Selection: ?usize,
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
        // try wall.loadThumbnailImageCached();
        // try wall.loadTexture();

        // set position
        wall.x = @as(i32, @intCast(i % cards_per_row * constants.THUMBNAIL_SIZE));
        wall.y = @as(i32, @intCast(@divFloor(i, cards_per_row) * constants.THUMBNAIL_SIZE));
    }

    var state = State{ .Selection = null };

    while (!rl.windowShouldClose()) {
        switch (state) {
            .Selection => |*selection| {
                if (rl.isKeyPressed(.left)) {
                    if (selection.*) |i| {
                        selection.* = if (i > 0) i - 1 else 0;
                    } else {
                        selection.* = 0;
                    }
                } else if (rl.isKeyPressed(.right)) {
                    if (selection.*) |i| {
                        selection.* = if (i < wallpapers.items.len - 1) i + 1 else selection.*;
                    } else {
                        selection.* = 0;
                    }
                } else if (rl.isKeyPressed(.up)) {
                    if (selection.*) |i| {
                        selection.* = if (i >= cards_per_row) i - cards_per_row else 0;
                    } else {
                        selection.* = 0;
                    }
                } else if (rl.isKeyPressed(.down)) {
                    if (selection.*) |i| {
                        selection.* = if (i < wallpapers.items.len - cards_per_row) i + cards_per_row else if (i % cards_per_row >= wallpapers.items.len % cards_per_row) wallpapers.items.len - 1 else selection.*;
                    } else {
                        selection.* = 0;
                    }
                } else if (selection.*) |s| {
                    if (rl.isKeyPressed(.space) or (rl.isMouseButtonPressed(.left) and wallpapers.items[s].isMouseOver())) {
                        state = State{ .Preview = s };
                    }
                }
                // check mouse hover
                const mouse_delta = rl.getMouseDelta();
                if (mouse_delta.x != 0 or mouse_delta.y != 0) {
                    selection.* = null;
                    for (wallpapers.items, 0..) |wall, i| {
                        if (wall.isMouseOver()) {
                            selection.* = i;
                        }
                    }
                }
            },
            .Preview => |preview| {
                if (rl.isKeyPressed(.backspace) or rl.isKeyPressed(.space) or rl.isMouseButtonPressed(.right)) {
                    state = State{ .Selection = preview };
                }
            },
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        switch (state) {
            .Selection => |selection| {
                for (wallpapers.items, 0..) |*wall, i| {
                    // const nameZ = try allocator.dupeZ(u8, std.fs.path.basename(path));
                    // defer allocator.free(nameZ);

                    if (i != selection) {
                        try wall.draw(false);
                    }

                    // rl.drawText(nameZ, 0, @as(i32, @intCast(i)) * 14, 12, .white);
                }

                if (selection) |i| {
                    try wallpapers.items[i].draw(true);
                }
            },
            .Preview => |i| {
                try wallpapers.items[i].preview();
            },
        }

        // Draw FPS counter
        var buffer: [50]u8 = undefined;
        const msg = try std.fmt.bufPrintZ(&buffer, "FPS: {d}", .{rl.getFPS()});
        rl.drawText(msg, screen_width - 48, screen_height - 14, 12, .white);
    }
}
