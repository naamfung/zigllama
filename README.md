# 🦙 zigllama - Ollama Zig Library

[![Zig](https://img.shields.io/badge/Zig-0.15.2-orange)](https://ziglang.org)
[![Ollama](https://img.shields.io/badge/Ollama-API-blue)](https://github.com/ollama/ollama)

The most comprehensive Ollama client library for Zig. Provides complete access to the [Ollama REST API](https://github.com/ollama/ollama/blob/main/docs/api.md) with streaming support and full type safety.

## Features

- ✅ **Full API Coverage** - All Ollama API endpoints supported
- ✅ **Streaming Support** - All responses support streaming by default
- ✅ **Type Safe** - Complete type definitions for requests and responses
- ✅ **Zero Dependencies** - Uses only Zig standard library
- ✅ **Zig 0.15.2+** - Updated for the latest Zig version

## API Coverage

| API | Description | Status |
|-----|-------------|--------|
| `chat` | Chat with models | ✅ |
| `generate` | Generate text | ✅ |
| `embed` | Generate embeddings (batch) | ✅ |
| `tags` | List local models | ✅ |
| `show` | Show model info | ✅ |
| `ps` | List running models | ✅ |
| `pull` | Pull model from registry | ✅ |
| `push` | Push model to registry | ✅ |
| `create` | Create custom model | ✅ |
| `copy` | Copy model | ✅ |
| `version` | Get Ollama version | ✅ |
| `delete` | Delete model | ✅ |

## Prerequisites

- [Ollama](https://ollama.com/download) installed and running
- At least one model pulled: `ollama pull llama3.2`
- Zig 0.15.2 or later

## Installation

### Method 1: Using `zig fetch`

```bash
zig fetch --save git+https://github.com/naamfung/zigllama.git
```

### Method 2: Add to `build.zig.zon`

```zig
.dependencies = .{
    .ollama = .{
        .url = "https://github.com/naamfung/zigllama/archive/main.tar.gz",
        .hash = "...", // Run zig fetch to get the hash
    },
},
```

### Add to your `build.zig`

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ollama_dep = b.dependency("ollama", .{
        .target = target,
        .optimize = optimize,
    });
    const ollama_mod = ollama_dep.module("ollama");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("ollama", ollama_mod);

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);
}
```

## Quick Start

```zig
const std = @import("std");
const Ollama = @import("ollama").Ollama;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize client
    var ollama = try Ollama.init(.{
        .host = "localhost",
        .port = 11434,
        .allocator = allocator,
    });
    defer ollama.deinit();

    // Simple chat
    var responses = try ollama.chat(.{
        .model = "llama3.2",
        .messages = &.{
            .{ .role = .user, .content = "Why is the sky blue?" },
        },
    });
    
    while (try responses.next()) |response| {
        std.debug.print("{s}", .{response.message.content});
    }
}
```

## Configuration

```zig
var ollama = try Ollama.init(.{
    .schema = "http",           // "http" or "https"
    .host = "localhost",        // Ollama server host
    .port = 11434,              // Ollama server port
    .allocator = allocator,
});
```

## API Reference

### Chat

Generate a chat response with conversation history.

```zig
var responses = try ollama.chat(.{
    .model = "llama3.2",
    .messages = &.{
        .{ .role = .system, .content = "You are a helpful assistant." },
        .{ .role = .user, .content = "Hello!" },
        .{ .role = .assistant, .content = "Hi! How can I help you?" },
        .{ .role = .user, .content = "What is Zig?" },
    },
    .stream = true,              // Enable streaming (default: true)
    .format = .json,             // Optional: force JSON output
    .keep_alive = 300000,        // Optional: keep model loaded (ms)
});

while (try responses.next()) |response| {
    std.debug.print("{s}", .{response.message.content});
    
    // Last response contains metrics
    if (response.done) {
        std.debug.print("\nTokens: {d}\n", .{response.eval_count.?});
    }
}
```

**Request fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | `[]const u8` | Yes | Model name |
| `messages` | `[]const Message` | Yes | Conversation history |
| `stream` | `bool` | No | Enable streaming (default: true) |
| `format` | `?Format` | No | Output format (`.json`, `.markdown`, etc.) |
| `tools` | `?[]const Tool` | No | Tools for function calling |
| `keep_alive` | `?u64` | No | Keep model loaded duration (ms) |

### Generate

Generate text from a single prompt.

```zig
var responses = try ollama.generate(.{
    .model = "llama3.2",
    .prompt = "Write a haiku about programming.",
    .stream = true,
    .options = .{
        .temperature = 0.7,
        .top_p = 0.9,
    },
});

while (try responses.next()) |response| {
    std.debug.print("{s}", .{response.response});
}
```

**Request fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | `[]const u8` | Yes | Model name |
| `prompt` | `?[]const u8` | No | Input prompt |
| `stream` | `bool` | No | Enable streaming (default: true) |
| `system` | `?[]const u8` | No | System prompt override |
| `template` | `?[]const u8` | No | Prompt template override |
| `context` | `?[]u32` | No | Context from previous response |
| `raw` | `?bool` | No | Skip prompt formatting |
| `images` | `?[]Image` | No | Base64 encoded images |
| `options` | `?Options` | No | Model parameters |

### Embed (Batch Embeddings)

Generate embeddings for multiple texts.

```zig
var input = std.ArrayList([]const u8).initCapacity(allocator, 2) catch return;
defer input.deinit(allocator);
try input.append(allocator, "The sky is blue because of rayleigh scattering");
try input.append(allocator, "Grass is green because of chlorophyll");

var responses = try ollama.embed(.{
    .model = "llama3.2",
    .input = try input.toOwnedSlice(allocator),
    .truncate = true,
});

while (try responses.next()) |response| {
    std.debug.print("Embeddings count: {d}\n", .{response.embeddings.len});
    for (response.embeddings) |embedding| {
        std.debug.print("Vector length: {d}\n", .{embedding.len});
    }
}
```

### Tags (List Models)

List all locally available models.

```zig
var responses = try ollama.tags();

while (try responses.next()) |response| {
    for (response.models) |model| {
        std.debug.print("Model: {s}\n", .{model.name});
        std.debug.print("  Size: {d} bytes\n", .{model.size});
        std.debug.print("  Family: {s}\n", .{model.details.family});
    }
}
```

### Show Model Information

Get detailed information about a model.

```zig
var responses = try ollama.show("llama3.2");

while (try responses.next()) |response| {
    std.debug.print("Template: {s}\n", .{response.template});
    std.debug.print("Parameters: {s}\n", .{response.parameters.?});
    std.debug.print("Family: {s}\n", .{response.details.family});
    
    if (response.model_info) |info| {
        std.debug.print("Parameter count: {d}\n", .{info.@"general.parameter_count".?});
    }
}
```

### Ps (Running Models)

List currently running models.

```zig
var responses = try ollama.ps();

while (try responses.next()) |response| {
    for (response.models) |model| {
        std.debug.print("Running: {s}\n", .{model.name});
        if (model.expires_at) |expires| {
            std.debug.print("  Expires: {s}\n", .{expires});
        }
    }
}
```

### Pull Model

Download a model from the registry.

```zig
var responses = try ollama.pull(.{
    .model = "llama3.2",
    .stream = true,
    .insecure = false,
});

while (try responses.next()) |response| {
    std.debug.print("Status: {s}\n", .{response.status});
    
    if (response.total) |total| {
        const completed = response.completed orelse 0;
        const percent = @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(total)) * 100;
        std.debug.print("Progress: {d:.1}%\n", .{percent});
    }
}
```

### Push Model

Upload a model to the registry.

```zig
var responses = try ollama.push(.{
    .model = "your-username/llama3.2-custom",
    .stream = true,
});

while (try responses.next()) |response| {
    std.debug.print("Status: {s}\n", .{response.status});
}
```

### Create Model

Create a custom model from an existing one.

```zig
var responses = try ollama.create(.{
    .model = "my-custom-model",
    .from = "llama3.2",
    .system = "You are a helpful coding assistant.",
    .template = "{{ .System }}\n{{ .Prompt }}",
});

while (try responses.next()) |response| {
    std.debug.print("Status: {s}\n", .{response.status});
}
```

### Copy Model

Copy a model to a new name.

```zig
const status = try ollama.copy("llama3.2", "my-backup/llama3.2");
if (status == .ok) {
    std.debug.print("Model copied successfully!\n", .{});
}
```

### Delete Model

Delete a model from local storage.

```zig
const status = try ollama.delete("my-custom-model");
if (status == .ok) {
    std.debug.print("Model deleted successfully!\n", .{});
}
```

**Note:** This operation is irreversible. Make sure you want to permanently remove the model before calling this function.

### Version

Get the Ollama server version.

```zig
var responses = try ollama.version();

while (try responses.next()) |response| {
    std.debug.print("Ollama version: {s}\n", .{response.version});
}
```

## Model Options

Fine-tune model behavior with the `Options` struct:

```zig
const options = types.Options{
    // Context settings
    .num_ctx = 4096,           // Context window size
    .num_batch = 512,          // Batch size for processing
    
    // GPU settings
    .num_gpu = 1,              // Number of GPU layers
    .main_gpu = 0,             // Main GPU index
    .low_vram = false,         // Low VRAM mode
    
    // Memory settings
    .use_mmap = true,          // Memory-mapped file
    .use_mlock = false,        // Lock memory in RAM
    
    // Sampling parameters
    .temperature = 0.7,        // Sampling temperature
    .top_p = 0.9,              // Nucleus sampling threshold
    .top_k = 40,               // Top-k sampling
    .seed = 42,                // Random seed for reproducibility
    
    // Generation limits
    .num_predict = 256,        // Maximum tokens to generate
    .num_keep = 0,             // Tokens to keep from prompt
    
    // Penalties
    .repeat_penalty = 1.1,     // Repetition penalty
    .presence_penalty = 0.0,   // Presence penalty
    .frequency_penalty = 0.0,  // Frequency penalty
    
    // Stop sequences
    .stop = &.{ "###", "\n\n" },
    
    // Mirostat settings
    .mirostat = 0,             // Mirostat version (0, 1, or 2)
    .mirostat_tau = 5.0,       // Mirostat target entropy
    .mirostat_eta = 0.1,       // Mirostat learning rate
};
```

## Types

### Role Enum

```zig
pub const Role = enum {
    user,       // User message
    assistant,  // AI assistant message
    system,     // System prompt
    tool,       // Tool response
};
```

### Message

```zig
pub const Message = struct {
    role: Role,                    // Message role
    content: []const u8,           // Message content
    images: ?[]Image = null,       // Optional base64 images
};
```

### Response Types

All responses are streamed and accessed through the iterator interface:

```zig
// Chat response
response.message.content      // Generated text
response.done                 // Is this the final chunk?
response.eval_count           // Tokens generated
response.total_duration       // Total processing time

// Generate response
response.response             // Generated text
response.context              // Context for next request
response.done

// Embed response
response.embeddings           // Array of embedding vectors
response.embeddings[i][j]     // Individual embedding value

// Pull/Push/Create response
response.status               // Status message
response.total                // Total bytes
response.completed            // Bytes completed
response.digest               // Content digest
```

## Complete Example: Chatbot

```zig
const std = @import("std");
const Ollama = @import("ollama").Ollama;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ollama = try Ollama.init(.{
        .host = "localhost",
        .port = 11434,
        .allocator = allocator,
    });
    defer ollama.deinit();

    // Conversation history
    var history = std.ArrayList(@import("ollama").types.Message)
        .initCapacity(allocator, 10) catch return;
    defer history.deinit(allocator);

    // System prompt
    try history.append(allocator, .{
        .role = .system,
        .content = "You are a helpful assistant. Keep responses concise.",
    });

    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    while (true) {
        try stdout.writeAll("\nYou: ");

        var input = std.ArrayList(u8).initCapacity(allocator, 256) catch return;
        defer input.deinit(allocator);

        stdin.reader().streamUntilDelimiter(
            input.writer(allocator), 
            '\n', 
            null
        ) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (input.items.len == 0) continue;
        if (std.mem.eql(u8, input.items, "quit")) break;

        // Add user message
        try history.append(allocator, .{
            .role = .user,
            .content = input.items,
        });

        // Stream response
        try stdout.writeAll("Assistant: ");
        var responses = try ollama.chat(.{
            .model = "llama3.2",
            .messages = history.items,
        });

        var assistant_msg = std.ArrayList(u8)
            .initCapacity(allocator, 1024) catch return;
        defer assistant_msg.deinit(allocator);

        while (try responses.next()) |response| {
            try stdout.writeAll(response.message.content);
            try assistant_msg.appendSlice(allocator, response.message.content);
        }

        // Add to history
        try history.append(allocator, .{
            .role = .assistant,
            .content = assistant_msg.items,
        });
    }

    try stdout.writeAll("\nGoodbye!\n");
}
```

## Error Handling

The library uses Zig's error handling throughout. Common errors:

```zig
var responses = ollama.chat(.{
    .model = "llama3.2",
    .messages = &messages,
}) catch |err| {
    switch (err) {
        error.OutOfMemory => {
            std.debug.print("Out of memory\n", .{});
        },
        else => {
            std.debug.print("Error: {any}\n", .{err});
        },
    }
    return;
};
```

## Examples

The `examples/` directory contains complete examples for each API:

- `chat` - Chat conversation example
- `generate` - Text generation example
- `embed` - Embedding generation example
- `show` - Show model information
- `tags` - List local models
- `ps` - List running models
- `pull` - Pull model from registry
- `push` - Push model to registry
- `create` - Create custom model
- `copy` - Copy model
- `delete` - Delete model
- `version` - Get Ollama version

Run any example:

```bash
zig build run-chat
zig build run-generate
zig build run-pull
# etc.
```

## Zig 0.15.2 Migration Notes

This library has been updated for Zig 0.15.2. Key changes from 0.14:

### ArrayList API

```zig
// Old (Zig 0.14)
var list = std.ArrayList(u8).init(allocator);
try list.append(item);
const slice = try list.toOwnedSlice();

// New (Zig 0.15.2)
var list = std.ArrayList(u8).initCapacity(allocator, 256) catch return;
try list.append(allocator, item);
const slice = try list.toOwnedSlice(allocator);
```

### HTTP Client

The HTTP client uses the new `std.http.Client` API with streaming responses through `std.Io.Reader`.

For more details, see the [Zig 0.15 release notes](https://ziglang.org/download/0.15.1/release-notes.html).

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Ollama](https://github.com/ollama/ollama) - The amazing local LLM runtime
- [Zig](https://ziglang.org) - The programming language
