const std = @import("std");

const print = std.debug.print;

pub const HaversinePair = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};

const JsonParser = struct {
    source: *std.ArrayList(u8),
    at: u64 = 0,
    hadError: u32 = 0,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: *std.ArrayList(u8)) !JsonParser {
        return JsonParser{
            .allocator = allocator,
            .source = input,
            .at = 0,
            .hadError = 0,
        };
    }

    fn ParseKeyword(this: *JsonParser, rest: []const u8, result: *JsonToken, tokentype: JsonTokenType) !void {
        const tokenstart = this.at;
        this.at += 1;

        if (rest.len > this.source.items.len - this.at) {
            return error.KeywordTooShort;
        }

        const check = this.source.items[this.at .. this.at + rest.len];
        if (!std.mem.eql(u8, check, rest)) {
            return error.IncorrectKeyword;
        }

        this.at += rest.len;
        const tokenend = this.at;

        result.type = tokentype;
        result.value = this.source.items[tokenstart..tokenend];
    }

    pub fn getJsonToken(this: *JsonParser) !JsonToken {
        var result: JsonToken = undefined;
        //var value = std.ArrayList(u8).init(this.allocator);
        //var result: JsonToken = JsonToken{ .type = JsonTokenType.Token_error, .value = &value };

        while (this.isWhiteSpace()) {
            this.at += 1;
        }

        if (this.at < this.source.items.len) {
            //result.value = this.source.items[this.at];
            //try result.value.append(this.source.items[this.at]);

            const val = this.source.items[this.at];
            switch (val) {
                '{' => {
                    result.type = JsonTokenType.Token_open_brace;
                },
                '}' => {
                    result.type = JsonTokenType.Token_close_brace;
                },
                '[' => {
                    result.type = JsonTokenType.Token_open_bracket;
                },
                ']' => {
                    result.type = JsonTokenType.Token_close_bracket;
                },
                ',' => {
                    result.type = JsonTokenType.Token_comma;
                },
                ':' => {
                    result.type = JsonTokenType.Token_colon;
                },
                ';' => {
                    result.type = JsonTokenType.Token_semi_colon;
                },

                'f' => {
                    try this.ParseKeyword("alse", &result, JsonTokenType.Token_false);
                },
                't' => {
                    try this.ParseKeyword("rue", &result, JsonTokenType.Token_false);
                },
                'n' => {
                    try this.ParseKeyword("ull", &result, JsonTokenType.Token_false);
                },

                '"' => {
                    this.at += 1;
                    result.type = JsonTokenType.Token_string_literal;
                    const stringstart = this.at;

                    while (this.at < this.source.items.len and this.source.items[this.at] != '"') {
                        if ((this.at + 1 < this.source.items.len) and this.source.items[this.at] == '\\' and this.source.items[this.at + 1] == '"') {
                            this.at += 1;
                        }
                        this.at += 1;
                    }

                    const stringend = this.at;
                    result.value = this.source.items[stringstart..stringend];

                    if (this.at < this.source.items.len) {
                        this.at += 1;
                    }
                },

                '-',
                '0',
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                => {},
                else => result.type = JsonTokenType.Token_error,
            }
        }

        print("JSON_TOKEN: {}\n", .{result});
        print("JSON_TOKEN_VALUE: {s}\n", .{result.value});
        return result;
    }

    fn isWhiteSpace(this: JsonParser) bool {
        if (this.at >= this.source.items.len) {
            return false;
        }

        const val = this.source.items[this.at];
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
    //value: *std.ArrayList(u8),
    value: []const u8,
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

fn parseJSON(input: *std.ArrayList(u8)) !void { // !JsonElement
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var json_parser = try JsonParser.init(allocator, input);

    const json_token = try json_parser.getJsonToken();
    print("{}\n", .{json_token});

    //const result = json_parser.parseJsonElement(null, json_token);
}

pub fn parseHaversinePairs(input: *std.ArrayList(u8), parsed_values: std.ArrayList(HaversinePair)) !u64 {
    //TODO: I need to initialize all the arraylists, figure out when and how
    var pair_count: u64 = 0;
    _ = parsed_values;
    pair_count += 1;

    const JSON = try parseJSON(input);
    std.debug.print("JSON: {}\n", .{JSON});

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
