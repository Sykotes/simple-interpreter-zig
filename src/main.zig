const std = @import("std");

const Token = enum {
    Push,
    Pop,
    Plus,
    Sub,
    Put,
};

const Operation = struct {
    token: Token,
    value: u8,
};

fn interpret(program: []const Operation) void {
    var stack: [128]i64 = undefined;
    var position: u64 = 0;

    for (program) |op| {
        switch (op.token) {
            .Push => {
                stack[position] = op.value;
                position += 1;
            },
            .Pop => {
                position -= 1;
            },
            .Plus => {
                position -= 1;
                const a = stack[position];
                position -= 1;
                const b = stack[position];

                stack[position] = a + b;
                position += 1;
            },
            .Sub => {
                position -= 1;
                const a = stack[position];
                position -= 1;
                const b = stack[position];

                stack[position] = b - a;
                position += 1;
            },
            .Put => {
                position -= 1;
                const a = stack[position];
                std.debug.print("{}\n", .{a});
            },
        }
    }
}

fn parse(alloc: std.mem.Allocator, source: []const u8) ![]Operation {
    var program = try std.ArrayList(Operation).initCapacity(alloc, 128);

    var lines = std.mem.tokenizeScalar(u8, source, '\n');
    while (lines.next()) |line| {
        var source_tokens = std.mem.tokenizeScalar(u8, line, ' ');
        while (source_tokens.next()) |t| {
            if (std.mem.eql(u8, t, ".")) {
                try program.append(alloc, .{ .token = Token.Put, .value = 0 });
            } else if (std.mem.eql(u8, t, "+")) {
                try program.append(alloc, .{ .token = Token.Plus, .value = 0 });
            } else if (std.mem.eql(u8, t, "-")) {
                try program.append(alloc, .{ .token = Token.Sub, .value = 0 });
            } else if (std.mem.eql(u8, t, "pop")) {
                try program.append(alloc, .{ .token = Token.Pop, .value = 0 });
            } else {
                const value: u8 = try std.fmt.parseInt(u8, t, 10);
                try program.append(alloc, .{ .token = Token.Push, .value = value});
            }
        }
    }

    return program.toOwnedSlice(alloc);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var threaded: std.Io.Threaded = .init(alloc);
    defer threaded.deinit();
    const io = threaded.io();

    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();

    const filename = if (argv.next()) |a| std.mem.sliceTo(a, 0) else {
        @panic("no file name provided");
    };

    const f = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer f.close();
    var read_buf: [2]u8 = undefined;
    var file_reader: std.fs.File.Reader = f.reader(io, &read_buf);
    var reader = &file_reader.interface;

    var contents = std.Io.Writer.Allocating.init(alloc);
    defer contents.deinit();

    _ = try reader.streamRemaining(&contents.writer);

    const contents_as_slice = try contents.toOwnedSlice();
    defer alloc.free(contents_as_slice);

    const program = try parse(alloc, contents_as_slice);
    defer alloc.free(program);

    interpret(program);
}
