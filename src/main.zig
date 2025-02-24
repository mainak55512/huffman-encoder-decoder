const std = @import("std");
const print = std.debug.print;

const Node = struct {
    element: ?u8,
    frequency: usize,
    isLeaf: bool,
    left: ?*Node,
    right: ?*Node,
};

pub fn createNode(alloc: std.mem.Allocator, isLeaf: bool, element: ?u8, frequency: usize, left: ?*Node, right: ?*Node) !*Node {
    const node = try alloc.create(Node);
    node.isLeaf = isLeaf;
    node.element = element;
    node.frequency = frequency;
    node.left = left;
    node.right = right;

    return node;
}

pub fn generateCodes(root: *Node, codeList: *std.ArrayList(bool), codeTable: *std.AutoHashMap(u8, []bool), codeListGarbage: *std.ArrayList([]bool)) !void {
    if (root.isLeaf) {
        var tempList = try codeList.clone();
        const codeStr = try tempList.toOwnedSlice();
        try codeListGarbage.append(codeStr);
        try codeTable.put(root.element.?, codeStr);
    }
    if (root.left) |left| {
        try codeList.append(false);
        try generateCodes(left, codeList, codeTable, codeListGarbage);
    }
    if (root.right) |right| {
        try codeList.append(true);
        try generateCodes(right, codeList, codeTable, codeListGarbage);
    }
    if (codeList.items.len > 0) {
        _ = codeList.pop();
    }
}

pub fn toBin(char: u8) [7]bool {
    var binary: [7]bool = [_]bool{false} ** 7;
    var temp: u8 = char;
    for (0..7) |i| {
        binary[6 - i] = if (temp % 2 == 0) false else true;
        temp /= 2;
    }
    return binary;
}

pub fn encodeTree(alloc: std.mem.Allocator, root: *Node, treeStr: *std.ArrayList(bool)) !void {
    const current = root;
    if (current.isLeaf) {
        try treeStr.append(true);
        const boolArr = toBin(current.element.?);
        // print("Encoded Tree Element: {any}\n", .{boolArr});
        for (boolArr) |elem| {
            try treeStr.append(elem);
        }
    } else {
        try treeStr.append(false);
        try encodeTree(alloc, current.left.?, treeStr);
        try encodeTree(alloc, current.right.?, treeStr);
    }
}

pub fn decodeTree() !void {}

pub fn decodeTreeElement(alloc: std.mem.Allocator, bit_reader: anytype) !u8 {
    var retrievedStr = std.ArrayList(u8).init(alloc);
    defer retrievedStr.deinit();
    for (0..7) |_| {
        const char = bit_reader.readBitsNoEof(u8, 1);
        if (char == error.EndOfStream) {
            break;
        } else {
            if (try char == 0) {
                try retrievedStr.append('0');
            } else {
                try retrievedStr.append('1');
            }
        }
    }
    var value: u8 = 0;
    for (retrievedStr.items, 0..) |elem, i| {
        value |= (elem - '0') << (6 - @as(u3, @intCast(i)));
    }
    return value;
}

pub fn compareNode(context: void, a: *Node, b: *Node) std.math.Order {
    _ = context;
    return std.math.order(a.*.frequency, b.*.frequency);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.log.err("Memory Leak!", .{});
    };
    const newAlloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(newAlloc);
    defer arena.deinit();

    const treeAlloc = arena.allocator();

    var hm = std.AutoHashMap(u8, usize).init(newAlloc);
    defer hm.deinit();

    const inp_file = try std.fs.cwd().openFile("test_bak.txt", .{});
    defer inp_file.close();

    const inpReader = inp_file.reader();
    const input = try inpReader.readAllAlloc(newAlloc, try inp_file.getEndPos());
    defer newAlloc.free(input);

    for (input) |item| {
        if (hm.get(item)) |val| {
            try hm.put(item, val + 1);
        } else {
            try hm.put(item, 1);
        }
    }

    var prQ = std.PriorityQueue(*Node, void, compareNode).init(newAlloc, {});
    defer prQ.deinit();

    var item_list = hm.iterator();
    while (item_list.next()) |item| {
        // print("\nElem: {c}, Freq: {}", .{ item.key_ptr.*, item.value_ptr.* });
        try prQ.add(try createNode(treeAlloc, true, item.key_ptr.*, item.value_ptr.*, null, null));
    }

    while (prQ.count() > 1) {
        const item1 = prQ.remove();
        const item2 = prQ.remove();
        const newFrequency = item1.*.frequency + item2.*.frequency;
        try prQ.add(try createNode(treeAlloc, false, null, newFrequency, item1, item2));
    }

    var treeStr = std.ArrayList(bool).init(newAlloc);
    defer treeStr.deinit();

    try encodeTree(newAlloc, prQ.items[0], &treeStr);

    // const encodedTreeStr = try treeStr.toOwnedSlice();
    // defer newAlloc.free(encodedTreeStr);

    // print("\nEncoded Tree: {s}\n", .{encodedTreeStr}); //01E001U1L01D01C001Z1K1M

    var codeList = std.ArrayList(bool).init(newAlloc);
    defer codeList.deinit();

    var codeListGarbage = std.ArrayList([]bool).init(newAlloc);
    defer codeListGarbage.deinit();
    defer for (codeListGarbage.items) |value| {
        newAlloc.free(value);
    };

    var codeTable = std.AutoHashMap(u8, []bool).init(newAlloc);
    defer codeTable.deinit();

    try generateCodes(prQ.items[0], &codeList, &codeTable, &codeListGarbage);

    var encodedStr = std.ArrayList(bool).init(newAlloc);
    defer encodedStr.deinit();

    for (input) |item| {
        if (codeTable.get(item)) |elem| {
            for (elem) |e| {
                try encodedStr.append(e);
            }
        }
    }

    // print("\nEncoded: {any}\n", .{encodedStr.items});

    const out_file = try std.fs.cwd().createFile("test_out.txt", .{});
    defer out_file.close();
    var buf_writer = std.io.bufferedWriter(out_file.writer());
    const writer = buf_writer.writer();
    var bit_writer = std.io.bitWriter(.little, writer);

    try bit_writer.writeBits(@as(u64, treeStr.items.len), 64); //write tree length
    try bit_writer.writeBits(@as(u64, encodedStr.items.len), 64); // write content length
    // try writer.writeAll(encodedTreeStr);

    for (treeStr.items) |item| {
        try bit_writer.writeBits(@as(u1, @intFromBool(item)), 1);
    }
    for (encodedStr.items) |item| {
        try bit_writer.writeBits(@as(u1, @intFromBool(item)), 1);
    }
    try bit_writer.flushBits();
    try buf_writer.flush();

    const dec_inp_file = try std.fs.cwd().openFile("test_out.txt", .{});
    defer dec_inp_file.close();

    const reader = dec_inp_file.reader();
    var bit_reader = std.io.bitReader(.little, reader);

    var retrievedStr = std.ArrayList(u8).init(newAlloc);
    defer retrievedStr.deinit();

    const treeLength = try bit_reader.readBitsNoEof(u64, 64);
    const filelength = try bit_reader.readBitsNoEof(u64, 64);
    // print("\n", .{});
    // print("Tree Length: {}\n", .{treeLength});
    // print("Content Length: {}\n", .{filelength});
    var strBuff = std.ArrayList(u8).init(newAlloc);
    defer strBuff.deinit();
    for (treeLength) |_| {
        const char = bit_reader.readBitsNoEof(u8, 1);
        if (char == error.EndOfStream) {
            break;
        } else {
            // print("\nreceived: {any}", .{char});
            if (try char == 0) {
                try strBuff.append('0');
            } else {
                try strBuff.append('1');
            }
        }
    }
    for (filelength) |_| {
        const char = bit_reader.readBitsNoEof(u8, 1);
        if (char == error.EndOfStream) {
            break;
        } else {
            // print("\nreceived: {any}", .{char});
            if (try char == 0) {
                try retrievedStr.append('0');
            } else {
                try retrievedStr.append('1');
            }
        }
    }

    const contentStr = try retrievedStr.toOwnedSlice();
    defer newAlloc.free(contentStr);
    const bitTree = try strBuff.toOwnedSlice();
    defer newAlloc.free(bitTree);

    // print("\nEncoded Tree: {s}\n", .{bitTree});
    // print("\nActual Content: {s}\n", .{input});
    // print("\nEncoded Content: {s}\n", .{contentStr});
}
