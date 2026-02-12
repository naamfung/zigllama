# Ollama Zig Library

The Ollama Zig library provides the easiest way to integrate Zig 0.15.2+ projects with [Ollama](https://github.com/ollama/ollama).

## Prerequisites

- [Ollama](https://ollama.com/download) should be installed and running
- Pull a model to use with the library: `ollama pull <model>` e.g. `ollama pull llama3.2`
  - See [Ollama.com](https://ollama.com/search) for more information on the models available.
- Zig 0.15.2 or later

## Install

```sh
zig fetch --save git+https://github.com/naamfung/zigllama.git
```

## Usage

Adding to build.zig
```zig
    const ollama = b.dependency("zigllama", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ollama", ollama.module("ollama"));
```

Import it in your code:
```zig 
const ollama = @import("ollama");
```

See [types.zig](src/types.zig) for more information on the response types.

## Streaming responses

Response streaming can be enabled by setting `.stream = true`.

```zig
try ollama.chat(.{ .model = "llama3.2", .stream = true, .messages = &.{
    .{ .role = .user, .content = "Why is the sky blue?" },
} });
```

## API

The Ollama Zig library's API is designed around the [Ollama REST API](https://github.com/ollama/ollama/blob/main/docs/api.md)

### Chat

```zig
    var responses = try ollama.chat(.{ .model = "llama3.2", .stream = false, .messages = &.{
        .{ .role = .user, .content = "Why is the sky blue?" },
    } });
    while (try responses.next()) |chat| {
        const content = chat.message.content;
        std.debug.print("{s}", .{content});
    }
```

### Generate

```zig
    var responses = try ollama.generate(.{ .model = "llama3.2", .prompt = "Why is the sky blue?" });
    while (try responses.next()) |response| {
        const content = response.response;
        std.debug.print("{s}", .{content});
    }

```

### Show

```zig
try ollama.show("llama3.2");
```

### Create

```zig
try ollama.create(.{ .model = "mario", .from = "llama3.2", .system = "You are Mario from Super Mario Bros." });
```

### Copy

```zig
try ollama.copy("llama3.2", "user/llama3.2");
```

### Delete
(In plan)Wait for the upstream update. see https://github.com/ollama/ollama/issues/8753
```zig
try ollama.delete("llama3.2")
```

### Pull

```zig
try ollama.pull("llama3.2")
```

### Push

```zig
try ollama.push(.{ .model = "dravenk/llama3.2"});
```

### Embed or Embed (batch)

**Note:** For Zig 0.15.2+, ArrayList methods require passing the allocator:

```zig
    var input = std.ArrayList([]const u8).initCapacity(allocator, 2) catch return;
    try input.append(allocator, "The sky is blue because of rayleigh scattering");
    try input.append(allocator, "Grass is green because of chlorophyll");

    var responses = try ollama.embed(.{
        .model = "dravenk/llama3.2",
        .input = try input.toOwnedSlice(allocator),
    });
    while (try responses.next()) |response| {
        std.debug.print("total_duration: {d}\n", .{response.total_duration.?});
        std.debug.print("prompt_eval_count: {d}\n", .{response.prompt_eval_count.?});
    }
```

### Ps

```zig
try ollama.ps()
```
### Version

```zig
try ollama.version()
```

## Errors

Errors are raised if requests return an error status or if an error is detected while streaming.

```zig
```

## Migration from Zig 0.14 to 0.15.2

This library has been updated for Zig 0.15.2. The main changes you need to be aware of:

### ArrayList Changes

In Zig 0.15.2, `std.ArrayList(T)` now uses the Unmanaged variant by default. This means:

**Before (Zig 0.14):**
```zig
var list = std.ArrayList(u8).init(allocator);
try list.append(item);
const slice = try list.toOwnedSlice();
```

**After (Zig 0.15.2):**
```zig
var list = std.ArrayList(u8).initCapacity(allocator, initial_capacity) catch return;
try list.append(allocator, item);
const slice = try list.toOwnedSlice(allocator);
```

Key changes:
- `init()` → Use `initCapacity(allocator, capacity)` or just use managed variant
- `append(item)` → `append(allocator, item)`
- `toOwnedSlice()` → `toOwnedSlice(allocator)`
- `deinit()` → `deinit(allocator)`

### HTTP Client

The HTTP client API remains largely compatible, but ensure you're using the latest patterns for request handling.

### Reader/Writer Interface

The new I/O interface (nicknamed "Writergate") changes how readers and writers work:
- `writer()` now requires passing the allocator: `writer(allocator)`
- Stream operations have been updated accordingly

For more details on Zig 0.15 breaking changes, see the [official release notes](https://ziglang.org/download/0.15.1/release-notes.html).
