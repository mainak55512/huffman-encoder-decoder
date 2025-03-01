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

pub fn encodeTree(root: *Node, treeStr: *std.ArrayList(bool)) !void {
    const current = root;
    if (current.isLeaf) {
        try treeStr.append(true);
        const boolArr = toBin(current.element.?);
        for (boolArr) |elem| {
            try treeStr.append(elem);
        }
    } else {
        try treeStr.append(false);
        try encodeTree(current.left.?, treeStr);
        try encodeTree(current.right.?, treeStr);
    }
}

pub fn decodeTree(alloc: std.mem.Allocator, treeLength: u64, bit_reader: anytype) ![]u8 {
    var length = treeLength;
    var strBuff = std.ArrayList(u8).init(alloc);
    while (length > 0) {
        const char = bit_reader.readBitsNoEof(u8, 1);
        if (char == error.EndOfStream) {
            break;
        } else {
            if (try char == 0) {
                try strBuff.append('0');
                length -= 1;
            } else {
                try strBuff.append('1');
                try strBuff.append(try decodeTreeElement(alloc, bit_reader));
                length -= 8;
            }
        }
    }
    const decodedTree = try strBuff.toOwnedSlice();
    strBuff.deinit();
    return decodedTree;
}

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

pub fn readEncodedContent(alloc: std.mem.Allocator, fileLength: u64, bit_reader: anytype) ![]u8 {
    var retrievedStr = std.ArrayList(u8).init(alloc);
    for (fileLength) |_| {
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
    const encodedContent = try retrievedStr.toOwnedSlice();
    retrievedStr.deinit();
    return encodedContent;
}

pub fn writeAllToFile(filePath: []const u8, encodedTree: std.ArrayList(bool), encodedContent: std.ArrayList(bool)) !void {
    const out_file = try std.fs.cwd().createFile(filePath, .{});
    defer out_file.close();
    var buf_writer = std.io.bufferedWriter(out_file.writer());
    const writer = buf_writer.writer();
    var bit_writer = std.io.bitWriter(.little, writer);

    try bit_writer.writeBits(@as(u64, encodedTree.items.len), 64); //write tree length
    try bit_writer.writeBits(@as(u64, encodedContent.items.len), 64); // write content length

    for (encodedTree.items) |item| {
        try bit_writer.writeBits(@as(u1, @intFromBool(item)), 1);
    }
    for (encodedContent.items) |item| {
        try bit_writer.writeBits(@as(u1, @intFromBool(item)), 1);
    }

    try bit_writer.flushBits();
    try buf_writer.flush();
}

pub const Error = error{EmptyArray};

pub fn readNext(elemArr: *std.ArrayList(u8)) !u8 {
    if (elemArr.items.len > 0) {
        return elemArr.orderedRemove(0);
    }
    return Error.EmptyArray;
}

pub fn rebuildTree(alloc: std.mem.Allocator, encodedTree: *std.ArrayList(u8)) !?*Node {
    if (encodedTree.items.len > 0) {
        const element = try readNext(encodedTree);
        if (element == '1') {
            const elem = try readNext(encodedTree);
            return try createNode(alloc, true, elem, 0, null, null);
        } else if (element == '0') {
            const left = try rebuildTree(alloc, encodedTree);
            const right = try rebuildTree(alloc, encodedTree);
            return try createNode(alloc, false, null, 0, left, right);
        }
    }
    return null;
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

    const inp_file = try std.fs.cwd().openFile("test.txt", .{});
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

    try encodeTree(prQ.items[0], &treeStr);

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

    try writeAllToFile("test_out.txt", treeStr, encodedStr);

    const dec_inp_file = try std.fs.cwd().openFile("test_out.txt", .{});
    defer dec_inp_file.close();

    const reader = dec_inp_file.reader();
    var bit_reader = std.io.bitReader(.little, reader);

    const treeLength = try bit_reader.readBitsNoEof(u64, 64);
    const filelength = try bit_reader.readBitsNoEof(u64, 64);

    const strBuff = try decodeTree(newAlloc, treeLength, &bit_reader);
    defer newAlloc.free(strBuff);

    var rebuildTreeStr = std.ArrayList(u8).init(newAlloc);
    defer rebuildTreeStr.deinit();
    try rebuildTreeStr.appendSlice(strBuff);

    const rebuiltTree = try rebuildTree(treeAlloc, &rebuildTreeStr);

    const contentStr = try readEncodedContent(newAlloc, filelength, &bit_reader);
    defer newAlloc.free(contentStr);

    print("\nEncoded Tree: {any}\n", .{rebuiltTree});
    // print("\nActual Content: {s}\n", .{input});
    print("\nEncoded Content: {s}\n", .{contentStr});
}
