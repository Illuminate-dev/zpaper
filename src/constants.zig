const std = @import("std");
const kf = @import("known-folders");

pub const THUMBNAIL_SIZE = 128;
pub const HOVER_SCALE = 1.2;
const WALLPAPER_DIR = "/Pictures/Wallpapers";

pub const SUPPORTED_FILETYPES = [_][]const u8{ ".jpg", ".jpeg", ".png" };
pub const DEFAULT_WIDTH = THUMBNAIL_SIZE * 6;
pub const DEFAULT_HEIGHT = THUMBNAIL_SIZE * 3;

const PathError = error{PathNotFound};

pub fn getCacheDir(allocator: std.mem.Allocator) ![]const u8 {
    return try kf.getPath(allocator, kf.KnownFolder.cache) orelse return PathError.PathNotFound;
}

pub fn getWallpaperDir(allocator: std.mem.Allocator) ![]const u8 {
    const homeDir = try kf.getPath(allocator, kf.KnownFolder.home) orelse return PathError.PathNotFound;
    defer allocator.free(homeDir);
    return try std.fmt.allocPrint(allocator, "{s}{s}", .{ homeDir, WALLPAPER_DIR });
}
