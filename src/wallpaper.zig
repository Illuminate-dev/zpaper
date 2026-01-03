const rl = @import("raylib");
const std = @import("std");

pub const THUMBNAIL_SIZE = 128;
const HOVER_SCALE = 1.2;
const WALLPAPER_DIR = "/home/henry/Pictures/Wallpapers/";
pub const CACHE_DIR = "/home/henry/.cache/zpaper/";

const SUPPORTED_FILETYPES = [_][]const u8{ ".jpg", ".jpeg", ".png" };

pub const Wallpaper = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    thumbnailImage: rl.Image = undefined,
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
        self.thumbnailImage.unload();
    }

    pub fn loadImage(self: *Wallpaper) !void {
        const fullpath = try std.fmt.allocPrintSentinel(self.allocator, "{s}{s}", .{ WALLPAPER_DIR, self.path }, 0);
        defer self.allocator.free(fullpath);

        self.thumbnailImage = try rl.loadImage(fullpath);

        const minLen = @min(self.thumbnailImage.height, self.thumbnailImage.width);
        const cr = rl.Rectangle{
            .width = @as(f32, @floatFromInt(minLen)),
            .height = @as(f32, @floatFromInt(minLen)),
            .x = @as(f32, @floatFromInt((self.thumbnailImage.width - minLen))) / 2.0,
            .y = @as(f32, @floatFromInt((self.thumbnailImage.height - minLen))) / 2.0,
        };

        self.thumbnailImage.crop(cr);
        self.thumbnailImage.resize(THUMBNAIL_SIZE, THUMBNAIL_SIZE);
    }

    pub fn loadImageCached(self: *Wallpaper) !void {
        const cache_path = try std.fmt.allocPrintSentinel(self.allocator, "{s}{s}", .{ CACHE_DIR, std.fs.path.basename(self.path) }, 0);
        defer self.allocator.free(cache_path);

        if (rl.fileExists(cache_path)) {
            self.thumbnailImage = try rl.loadImage(cache_path);
        } else {
            try self.loadImage();
            _ = rl.exportImage(self.thumbnailImage, cache_path);
        }
    }

    pub fn loadTexture(self: *Wallpaper) !void {
        self.texture = try rl.loadTextureFromImage(self.thumbnailImage);
    }

    pub fn draw(self: Wallpaper, isHovered: bool) void {
        if (isHovered) {
            const offset = (THUMBNAIL_SIZE * (HOVER_SCALE - 1)) / 2.0;
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

    const dir = try std.fs.openDirAbsolute(WALLPAPER_DIR, .{ .iterate = true });

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        for (SUPPORTED_FILETYPES) |filetype| {
            if (std.mem.eql(u8, std.fs.path.extension(entry.path), filetype)) {
                const wallpaper = try Wallpaper.open(allocator, try allocator.dupe(u8, entry.path));
                try walls.append(allocator, wallpaper);
                break;
            }
        }
    }

    return walls;
}
