const std = @import("std");
const Ollama = @import("ollama").Ollama;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ollama = try Ollama.init(.{ .host = "localhost", .port = 11434, .allocator = allocator });
    defer ollama.deinit();

    const status: std.http.Status = try ollama.delete("dravenk/llama3.2");
    if (status == std.http.Status.ok) {
        std.debug.print("deleted model, status:{any}\n", .{status});
    } else {
        std.debug.print("failed to delete model, status:{any}\n", .{status});
    }
}
