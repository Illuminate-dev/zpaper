const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const constants = @import("constants.zig");

pub const Wallpaper = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    full_path: []const u8,
    image: rl.Image = undefined,
    image_status: enum { Unloaded, Thumbnail, Full } = .Unloaded,
    texture: rl.Texture = undefined,
    x: i32 = 0,
    y: i32 = 0,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Wallpaper {
        const wall_dir = try constants.getWallpaperDir(allocator);
        defer allocator.free(wall_dir);
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ wall_dir, path });
        const w: Wallpaper = .{
            .allocator = allocator,
            .path = path,
            .full_path = full_path,
        };

        return w;
    }

    pub fn deinit(self: *Wallpaper) void {
        self.allocator.free(self.path);
        self.allocator.free(self.full_path);
        self.texture.unload();
        self.image.unload();
    }

    pub fn loadImageFull(self: *Wallpaper) !void {
        const full_pathZ = try std.fmt.allocPrintSentinel(self.allocator, "{s}", .{self.full_path}, 0);
        defer self.allocator.free(full_pathZ);

        self.image = try rl.loadImage(full_pathZ);
        self.image_status = .Full;
    }

    fn cropImageToThumbnail(image: *rl.Image) !void {
        const minLen = @min(image.height, image.width);
        const cr = rl.Rectangle{
            .width = @as(f32, @floatFromInt(minLen)),
            .height = @as(f32, @floatFromInt(minLen)),
            .x = @as(f32, @floatFromInt((image.width - minLen))) / 2.0,
            .y = @as(f32, @floatFromInt((image.height - minLen))) / 2.0,
        };

        image.crop(cr);
        image.resize(constants.THUMBNAIL_SIZE, constants.THUMBNAIL_SIZE);
    }

    pub fn loadThumbnailImageCached(self: *Wallpaper) !void {
        const cache_dir = try constants.getCacheDir(self.allocator);
        defer self.allocator.free(cache_dir);
        const cached_path = try std.fmt.allocPrintSentinel(self.allocator, "{s}/{s}", .{ cache_dir, std.fs.path.basename(self.path) }, 0);
        defer self.allocator.free(cached_path);

        if (rl.fileExists(cached_path)) {
            self.image = try rl.loadImage(cached_path);
        } else {
            try self.loadImageFull();
            try Wallpaper.cropImageToThumbnail(&self.image);
            _ = rl.exportImage(self.image, cached_path);
        }
        self.image_status = .Thumbnail;
    }

    pub fn loadTexture(self: *Wallpaper) !void {
        self.texture = try rl.loadTextureFromImage(self.image);
    }

    pub fn draw(self: *Wallpaper, isHovered: bool) !void {
        if (isHovered) {
            const offset = (constants.THUMBNAIL_SIZE * (constants.HOVER_SCALE - 1)) / 2.0;
            const newX = @as(f32, @floatFromInt(self.x)) - offset;
            const newY = @as(f32, @floatFromInt(self.y)) - offset;
            rl.drawTextureEx(
                self.texture,
                rl.Vector2{
                    .x = newX,
                    .y = newY,
                },
                0.0,
                1.2,
                .white,
            );
        } else {
            rl.drawTexture(self.texture, self.x, self.y, .white);
        }
    }

    pub fn preview(self: *Wallpaper) !void {
        rl.drawTexture(self.texture, 0, 0, .white);

        // rl.drawTextureEx(
        //     self.texture,
        //     rl.Vector2{
        //         .x = ,
        //         .y = newY,
        //     },
        //     0.0,
        //     1.2,
        //     .white,
        // );
    }

    pub fn isMouseOver(self: Wallpaper) bool {
        const rec = rl.Rectangle{
            .x = @as(f32, @floatFromInt(self.x)),
            .y = @as(f32, @floatFromInt(self.y)),
            .width = constants.THUMBNAIL_SIZE,
            .height = constants.THUMBNAIL_SIZE,
        };
        return rl.checkCollisionPointRec(rl.getMousePosition(), rec);
    }

    pub fn setAsWallpaper(self: Wallpaper) !void {
        if (comptime builtin.target.os.tag == .macos) {
            const script = try std.fmt.allocPrint(self.allocator, "tell application \"System Events\" to tell every desktop to set picture to \"{s}\" as POSIX file", .{self.full_path});
            defer self.allocator.free(script);
            const osascript_args = &[_][]const u8{
                "osascript",
                "-e",
                script,
            };

            const out = try std.process.Child.run(.{ .argv = osascript_args, .allocator = self.allocator });
            defer {
                self.allocator.free(out.stdout);
                self.allocator.free(out.stderr);
            }
            std.debug.print("{s}\n", .{out.stdout});
            std.debug.print("{s}\n", .{out.stderr});
        } else {
            // nothing for now
        }
    }
};

pub fn getWallpapers(allocator: std.mem.Allocator) !std.ArrayList(Wallpaper) {
    var walls = std.ArrayList(Wallpaper).empty;

    const dir_path = try constants.getWallpaperDir(allocator);
    defer allocator.free(dir_path);
    const dir = try std.fs.openDirAbsolute(dir_path, .{ .iterate = true });

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        for (constants.SUPPORTED_FILETYPES) |filetype| {
            if (std.mem.eql(u8, std.fs.path.extension(entry.path), filetype)) {
                const wallpaper = try Wallpaper.open(allocator, try allocator.dupe(u8, entry.path));
                try walls.append(allocator, wallpaper);
                break;
            }
        }
    }

    return walls;
}
