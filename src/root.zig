const std = @import("std");
const rl = @import("raylib");
const wp = @import("wallpaper.zig");
const constants = @import("constants.zig");

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

    const screenWidth = constants.DEFAULT_WIDTH;
    const screenHeight = constants.DEFAULT_HEIGHT;
    rl.initWindow(screenWidth, screenHeight, "Zpaper");
    defer rl.closeWindow();

    rl.setWindowState(.{ .window_resizable = false, .window_topmost = true });

    rl.setTargetFPS(60);
    rl.setWindowMonitor(1);

    var wallpapers = try wp.getWallpapers(allocator);
    defer {
        for (wallpapers.items) |*wall| wall.deinit();
        wallpapers.deinit(allocator);
    }

    const cardsPerRow = constants.DEFAULT_WIDTH / constants.THUMBNAIL_SIZE;
    // const rows = constants.DEFAULT_HEIGHT / constants..THUMBNAIL_SIZE;

    for (wallpapers.items, 0..) |*wall, i| {
        // load texture
        try wall.loadImageCached();
        try wall.loadTexture();

        // set position
        wall.x = @as(i32, @intCast(i % cardsPerRow * constants.THUMBNAIL_SIZE));
        wall.y = @as(i32, @intCast(@divFloor(i, cardsPerRow) * constants.THUMBNAIL_SIZE));
    }

    var hover: ?usize = null;

    while (!rl.windowShouldClose()) {
        // check hovering
        hover = null;
        for (wallpapers.items, 0..) |wall, i| {
            const rec = rl.Rectangle{
                .x = @as(f32, @floatFromInt(wall.x)),
                .y = @as(f32, @floatFromInt(wall.y)),
                .width = constants.THUMBNAIL_SIZE,
                .height = constants.THUMBNAIL_SIZE,
            };
            if (rl.checkCollisionPointRec(rl.getMousePosition(), rec)) {
                hover = i;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        for (wallpapers.items, 0..) |wall, i| {
            // const nameZ = try allocator.dupeZ(u8, std.fs.path.basename(path));
            // defer allocator.free(nameZ);

            if (i != hover) {
                wall.draw(false);
            }

            // rl.drawText(nameZ, 0, @as(i32, @intCast(i)) * 14, 12, .white);
        }

        if (hover) |i| {
            wallpapers.items[i].draw(true);
        }

        // Draw FPS
        var buffer: [50]u8 = undefined;
        const msg = try std.fmt.bufPrintZ(&buffer, "FPS: {d}", .{rl.getFPS()});
        rl.drawText(msg, screenWidth - 48, screenHeight - 14, 12, .white);
    }
}
