const std = @import("std");
const huff = @import("./encoder-decoder.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory Leak!", .{});
    };
    const newAlloc = gpa.allocator();

    // try huff.huffEncoder(newAlloc, "./src/encoder-decoder.zig", "test.mhuff");
    try huff.huffDecoder(newAlloc, "test.mhuff", "decoded.txt");
}
