const std = @import("std");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const args = args: {
        if (init.minimal.args.vector.len <= 1) {
            std.log.err("missing arguments", .{});
            return error.MissingArgs;
        }
        var args = init.minimal.args.iterate();
        _ = args.skip();
        while (args.next()) |arg| {
            std.log.debug("{s}", .{arg});
        }
        break :args .{};
    };
    _ = args;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), init.io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    // try stdout_writer.print("", .{});
    try stdout_writer.flush();
}
