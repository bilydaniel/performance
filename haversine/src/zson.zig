const std = @import("std");

const print = std.debug.print;

pub const HaversinePair = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};

const JsonParser = struct {
    source: std.ArrayList(u8),
    at: u64,
    hadError: u32,

    pub fn getJsonToken(this: JsonParser) !JsonToken {
        var result: JsonToken = undefined;
        result.type = JsonTokenType.Token_error;

        while (this.isWhiteSpace()) {
            this.at += 1;
        }

        return result;
    }

    fn isWhiteSpace(this: JsonParser) bool {
        if (this.at >= this.source.len) {
            return false;
        }

        const val = this.source[this.at];
        return val == ' ' or val == '\t' or val == '\n' or val == '\r';
    }

    //pub fn parseJsonElement(this: JsonParser, label: std.ArrayList(u8), value: JsonToken) !JsonElement {}
};

const JsonElement = struct {
    label: std.ArrayList(u8),
    value: std.ArrayList(u8),
    firstSubElement: *JsonElement,
    nextSibling: *JsonElement,
};

const JsonValue = union(enum) {
    null,
    boolean: bool,
    number: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringHashMap(JsonValue),
};

const JsonTokenType = enum {
    Token_end_of_stream,
    Token_error,

    Token_open_brace,
    Token_open_bracket,
    Token_close_brace,
    Token_close_bracket,
    Token_comma,
    Token_colon,
    Token_semi_colon,
    Token_string_literal,
    Token_number,
    Token_true,
    Token_false,
    Token_null,

    Token_count,
};

const JsonToken = struct {
    type: JsonTokenType,
    value: std.ArrayList(u8),
};

pub fn parse(file: *std.fs.File) !JsonValue {
    try file.seekTo(0);
    var char: u8 = undefined;
    while (true) {
        char = file.reader().readByte() catch |err| {
            print("READING ERROR: {}\n", .{err});
            break;
        };
        //print("{}\n", .{char});
    }
    print("{}", .{file});
    const value = JsonValue{ .null = {} };
    print("{}", .{value});

    return JsonValue{ .null = {} };
}

fn parseJSON(input: []u8) !JsonElement {
    var json_parser = JsonParser{};
    json_parser.source = input;

    const json_token = json_parser.getJsonToken();
    print("{s}\n", .{json_token});
    //const result = json_parser.parseJsonElement(null, json_token);
}

pub fn parseHaversinePairs(input: []u8, parsed_values: std.ArrayList(HaversinePair)) !u64 {
    //TODO: I need to initialize all the arraylists, figure out when and how
    var pair_count: u64 = 0;
    _ = parsed_values;
    pair_count += 1;

    const JSON = parseJSON(input);

    return pair_count;
}

const Pair = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};
const Data = struct {
    pairs: []const Pair,
};
pub fn asd() i64 {
    std.debug.print("{}\n", .{69});
    return 42;
}

pub fn mock() !Data {
    const data = Data{
        .pairs = &.{
            Pair{ .x0 = -96.59575683104899, .y0 = 30.788588467490378, .x1 = -87.46731317954121, .y1 = 1.8445901235399873 },
            Pair{ .x0 = 67.69145235694036, .y0 = 74.09065077126873, .x1 = 51.285092428591696, .y1 = 90 },
            Pair{ .x0 = 125.30291071996822, .y0 = 90, .x1 = 35.04410898291682, .y1 = 59.80779892671494 },
            Pair{ .x0 = 124.85635899390746, .y0 = 68.84789321130262, .x1 = 65.74380201730972, .y1 = 43.646871427123315 },
        },
    };
    return data;
}
