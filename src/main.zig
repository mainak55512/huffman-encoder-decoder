const std = @import("std");
const huff = @import("./encoder-decoder.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory Leak!", .{});
    };
    const newAlloc = gpa.allocator();

    // try huff.huffEncoder(newAlloc, "test.txt", "test.mhuff");
    try huff.huffDecoder(newAlloc, "test.mhuff", "test_decoded.txt");
}
