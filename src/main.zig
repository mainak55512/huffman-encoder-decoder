const std = @import("std");
const huff = @import("./encoder-decoder.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory Leak!", .{});
    };
    const newAlloc = gpa.allocator();

    const args = try std.process.argsAlloc(newAlloc);
    defer std.process.argsFree(newAlloc, args);

    if (args.len == 3) {
        var fileNameParts = std.ArrayList([]const u8).init(newAlloc);
        defer fileNameParts.deinit();
        var it = std.mem.splitScalar(u8, args[2], '.');
        while (it.next()) |elem| {
            try fileNameParts.append(elem);
        }
        const ext = fileNameParts.pop();
        if (std.mem.eql(u8, args[1], "encode")) {
            if (!std.mem.eql(u8, ext, "mhuff")) {
                try fileNameParts.append(".mhuff");
                var outFile = std.ArrayList(u8).init(newAlloc);
                defer outFile.deinit();
                for (fileNameParts.items) |elem| {
                    try outFile.appendSlice(elem);
                }
                const outFileName = try outFile.toOwnedSlice();
                defer newAlloc.free(outFileName);
                try huff.huffEncoder(newAlloc, args[2], outFileName);
            } else {
                std.log.err("File can't be encoded.\n", .{});
            }
        } else if (std.mem.eql(u8, args[1], "decode")) {
            if (std.mem.eql(u8, ext, "mhuff")) {
                try fileNameParts.append("_decoded.txt");
                var outFile = std.ArrayList(u8).init(newAlloc);
                defer outFile.deinit();
                for (fileNameParts.items) |elem| {
                    try outFile.appendSlice(elem);
                }
                const outFileName = try outFile.toOwnedSlice();
                defer newAlloc.free(outFileName);
                try huff.huffDecoder(newAlloc, args[2], outFileName);
            } else {
                std.log.err("File can't be decoded.\n", .{});
            }
        } else {
            std.log.err("Illegal command.\n", .{});
        }
    } else {
        std.log.err("Incorrect number of arguments.\n", .{});
    }
}
