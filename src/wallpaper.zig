const rl = @import("raylib");
const std = @import("std");
const constants = @import("constants.zig");

pub const Wallpaper = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    thumbnail_image: rl.Image = undefined,
    texture: rl.Texture = undefined,
    x: i32 = 0,
    y: i32 = 0,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Wallpaper {
        const w: Wallpaper = .{
            .allocator = allocator,
            .path = path,
        };

        return w;
    }

    pub fn deinit(self: *Wallpaper) void {
        self.allocator.free(self.path);
        self.texture.unload();
        self.thumbnail_image.unload();
    }

    pub fn loadImage(self: *Wallpaper) !void {
        const wall_dir = try constants.getWallpaperDir(self.allocator);
        defer self.allocator.free(wall_dir);
        const full_path = try std.fmt.allocPrintSentinel(self.allocator, "{s}/{s}", .{ wall_dir, self.path }, 0);
        defer self.allocator.free(full_path);

        self.thumbnail_image = try rl.loadImage(full_path);

        const minLen = @min(self.thumbnail_image.height, self.thumbnail_image.width);
        const cr = rl.Rectangle{
            .width = @as(f32, @floatFromInt(minLen)),
            .height = @as(f32, @floatFromInt(minLen)),
            .x = @as(f32, @floatFromInt((self.thumbnail_image.width - minLen))) / 2.0,
            .y = @as(f32, @floatFromInt((self.thumbnail_image.height - minLen))) / 2.0,
        };

        self.thumbnail_image.crop(cr);
        self.thumbnail_image.resize(constants.THUMBNAIL_SIZE, constants.THUMBNAIL_SIZE);
    }

    pub fn loadImageCached(self: *Wallpaper) !void {
        const cache_dir = try constants.getCacheDir(self.allocator);
        defer self.allocator.free(cache_dir);
        const cached_path = try std.fmt.allocPrintSentinel(self.allocator, "{s}/{s}", .{ cache_dir, std.fs.path.basename(self.path) }, 0);
        defer self.allocator.free(cached_path);

        if (rl.fileExists(cached_path)) {
            self.thumbnail_image = try rl.loadImage(cached_path);
        } else {
            try self.loadImage();
            _ = rl.exportImage(self.thumbnail_image, cached_path);
        }
    }

    pub fn loadTexture(self: *Wallpaper) !void {
        self.texture = try rl.loadTextureFromImage(self.thumbnail_image);
    }

    pub fn draw(self: Wallpaper, isHovered: bool) void {
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
