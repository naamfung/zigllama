const std = @import("std");

pub const types = @import("types.zig");
pub const Api = @import("api.zig").Api;

fn ResponseStream(comptime T: type) type {
    return struct {
        response: *std.http.Client.Response,
        allocator: std.mem.Allocator,
        var done: bool = false;

        pub fn deinit(self: @This()) void {
            self.response.request.deinit();
            self.response.request.client.allocator.destroy(self.response.request.client);
            self.allocator.destroy(self.response);
        }

        pub fn next(self: @This()) !?T {
            const allocator = self.allocator;
            if (done) {
                return null;
            }

            // Use an allocating writer to collect the response
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();

            // Get the body reader using bodyReaderDecompressing which returns *std.Io.Reader
            var transfer_buffer: [64]u8 = undefined;
            var decompress: std.http.Decompress = undefined;
            
            const body_reader = self.response.request.reader.bodyReaderDecompressing(
                &transfer_buffer,
                self.response.head.transfer_encoding,
                self.response.head.content_length,
                self.response.head.content_encoding,
                &decompress,
                &.{},
            );

            _ = body_reader.streamDelimiter(&aw.writer, '\n') catch |err| {
                switch (err) {
                    error.EndOfStream => {
                        done = true;
                    },
                    else => return err,
                }
            };

            if (aw.written().len == 0) {
                done = true;
                return null;
            }
            const response = try aw.toOwnedSlice();

            if (self.response.head.status.class() != .success) {
                std.debug.print("Response: {s}\n", .{response});
                done = true;

                const parsed = try std.json.parseFromSlice(T.@"error", allocator, response, .{
                    .ignore_unknown_fields = true,
                });
                std.debug.print("Error: {s}", .{parsed.value.@"error"});

                return null;
            }

            const parsed = std.json.parseFromSlice(T, allocator, response, .{
                .ignore_unknown_fields = true,
            }) catch |err| {
                std.debug.print("Parsing response: {s} | err {any}\n", .{ response, err });
                done = true;
                return null;
            };

            // check if T have a field done
            if (@hasField(T, "done")) {
                done = parsed.value.done;
            }

            // check if T have a field status
            if (@hasField(T, "status")) {
                if (std.mem.eql(u8, parsed.value.status, "success")) {
                    done = true;
                }
            }

            return parsed.value;
        }
    };
}

pub const Ollama = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    schema: []const u8 = "http",

    host: []const u8 = "localhost",
    port: u16 = 11434,

    pub fn init(self: Self) !Ollama {
        return .{ .allocator = self.allocator };
    }
    pub fn deinit(self: *Self) void {
        self.allocator = undefined;
    }

    // model='llama3.2', messages=[{'role': 'user', 'content': 'Why is the sky blue?'}]
    pub fn chat(self: *Self, opts: types.Request.chat) !ResponseStream(types.Response.chat) {
        const response = try self.createRequest(Api.chat, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn generate(self: *Self, opts: types.Request.generate) !ResponseStream(types.Response.generate) {
        const response = try self.createRequest(Api.generate, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn ps(self: *Self) !ResponseStream(types.Response.ps) {
        const response = try self.noBodyRequest(Api.ps);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn embed(self: *Self, opts: types.Request.embed) !ResponseStream(types.Response.embed) {
        const response = try self.createRequest(Api.embed, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn version(self: *Self) !ResponseStream(types.Response.version) {
        const response = try self.noBodyRequest(Api.version);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn tags(self: *Self) !ResponseStream(types.Response.tags) {
        const response = try self.noBodyRequest(Api.tags);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn show(self: *Self, model: []const u8) !ResponseStream(types.Response.show) {
        const opts: types.Request.show = .{ .model = model };
        const response = try self.createRequest(Api.show, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn create(self: *Self, opts: types.Request.create) !ResponseStream(types.Response.create) {
        const response = try self.createRequest(Api.show, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn push(self: *Self, opts: types.Request.push) !ResponseStream(types.Response.push) {
        const response = try self.createRequest(Api.push, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn pull(self: *Self, opts: types.Request.pull) !ResponseStream(types.Response.pull) {
        const response = try self.createRequest(Api.pull, opts);
        const response_ptr = try self.allocator.create(std.http.Client.Response);
        response_ptr.* = response;
        return .{ .response = response_ptr, .allocator = self.allocator };
    }

    pub fn copy(self: *Self, source: []const u8, destination: []const u8) !std.http.Status {
        const opts: types.Request.copy = .{
            .source = source,
            .destination = destination,
        };
        var response = try self.createRequest(Api.copy, opts);
        defer {
            response.request.deinit();
            response.request.client.allocator.destroy(response.request.client);
        }
        return response.head.status;
    }

    fn noBodyRequest(self: *Self, api_type: Api) !std.http.Client.Response {
        const client = try self.allocator.create(std.http.Client);
        errdefer self.allocator.destroy(client);
        client.* = std.http.Client{ .allocator = self.allocator };

        const api_str = api_type.path();
        const method = api_type.method();
        const url = try std.fmt.allocPrint(self.allocator, "{s}://{s}:{any}{s}", .{ self.schema, self.host, self.port, api_str });
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);
        
        var req = try client.request(method, uri, .{
            .keep_alive = false,
        });
        
        try req.sendBodiless();
        try req.connection.?.flush();
        
        // Receive response
        var redirect_buffer: [8 * 1024]u8 = undefined;
        return try req.receiveHead(&redirect_buffer);
    }

    fn createRequest(self: *Self, api_type: Api, values: anytype) !std.http.Client.Response {
        const client = try self.allocator.create(std.http.Client);
        errdefer self.allocator.destroy(client);
        client.* = std.http.Client{ .allocator = self.allocator };

        const api_str = api_type.path();
        const method = api_type.method();
        const url = try std.fmt.allocPrint(self.allocator, "{s}://{s}:{any}{s}", .{ self.schema, self.host, self.port, api_str });
        defer self.allocator.free(url);

        const uri = try std.Uri.parse(url);
        
        var req = try client.request(method, uri, .{
            .keep_alive = false,
        });
        
        // Serialize values to JSON using Allocating writer
        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();
        
        {
            var json_writer: std.json.Stringify = .{
                .writer = &aw.writer,
                .options = .{
                    .emit_null_optional_fields = false,
                },
            };
            try json_writer.write(values);
        }

        const payload = try aw.toOwnedSlice();
        
        req.transfer_encoding = .{ .content_length = payload.len };
        var body = try req.sendBodyUnflushed(&.{});
        try body.writer.writeAll(payload);
        try body.end();
        try req.connection.?.flush();
        
        // Receive response
        var redirect_buffer: [8 * 1024]u8 = undefined;
        return try req.receiveHead(&redirect_buffer);
    }
};
