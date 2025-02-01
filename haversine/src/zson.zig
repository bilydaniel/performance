const std = @import("std");

const print = std.debug.print;

pub const HaversinePair = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};

const JsonParseError = error{
    UnexpectedToken,
    ExpectedColon,
    ExpectedComma,
    AllocationFailed,
    OutOfMemory,
};

const JsonParser = struct {
    source: *std.ArrayList(u8),
    at: u64 = 0,
    hadError: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: *std.ArrayList(u8)) !JsonParser {
        return JsonParser{
            .allocator = allocator,
            .source = input,
            .at = 0,
            .hadError = false,
        };
    }

    fn ParseKeyword(this: *JsonParser, rest: []const u8, result: *JsonToken, tokentype: JsonTokenType) !void {
        const tokenstart = this.at;
        this.at += 1;

        if (rest.len <= this.source.items.len - this.at) {
            const check = this.source.items[this.at .. this.at + rest.len];
            if (std.mem.eql(u8, check, rest)) {
                this.at += rest.len;
                const tokenend = this.at;

                result.type = tokentype;
                result.value = this.source.items[tokenstart..tokenend];
            }
        }
    }

    fn IsJsonDigit(this: *JsonParser) bool {
        var result = false;

        if (this.at < this.source.items.len) {
            const val = this.source.items[this.at];
            result = (val >= '0' and val <= '9');
        }
        return result;
    }

    pub fn getJsonToken(this: *JsonParser) JsonToken {
        var result: JsonToken = undefined;
        result.value = "";

        while (this.isWhiteSpace()) {
            this.at += 1;
        }

        if (this.at < this.source.items.len) {
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
                => {
                    result.type = JsonTokenType.Token_number;
                    const numberstart = this.at;

                    if (val == '-') {
                        this.at += 1;
                    }

                    if (val != '0') {
                        while (this.IsJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    if (this.at < this.source.items.len and this.source.items[this.at] == '.') {
                        this.at += 1;
                        while (this.IsJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    if (this.at < this.source.items.len and (this.source.items[this.at] == 'e' or this.source.items[this.at] == 'E')) {
                        this.at += 1;

                        if (this.at < this.source.items.len and (this.source.items[this.at] == '+' or this.source.items[this.at] == '-')) {
                            this.at += 1;
                        }

                        while (this.IsJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    const numberend = this.at;
                    result.value = this.source.items[numberstart..numberend];
                },
                else => result.type = JsonTokenType.Token_error,
            }
        }

        return result;
    }

    fn isWhiteSpace(this: JsonParser) bool {
        if (this.at >= this.source.items.len) {
            return false;
        }

        const val = this.source.items[this.at];
        return val == ' ' or val == '\t' or val == '\n' or val == '\r';
    }

    pub fn inBounds(this: *@This()) bool {
        return (this.at < this.source.items.len);
    }

    pub fn isParsing(this: *@This()) bool {
        return (!this.hadError and this.inBounds());
    }

    pub fn Error(this: *@This(), token: JsonToken, msg: []const u8) void {
        this.hadError = true;
        std.debug.print("ERROR: parser: {}, token:{}, msg:{s}\n", .{ this, token, msg });
    }

    pub fn parseJsonList(this: *@This(), endtoken: JsonTokenType, hasLabel: bool) JsonParseError!?*JsonElement {
        var firstElement: ?*JsonElement = null;
        var lastElement: ?*JsonElement = null;
        var label: []const u8 = "";

        while (this.isParsing()) {
            var val = this.getJsonToken();
            if (hasLabel) {
                std.debug.print("DEBUG_VALUE: {}", .{val});
                if (val.type == JsonTokenType.Token_string_literal) {
                    label = val.value;
                    const colon = this.getJsonToken();
                    if (colon.type == JsonTokenType.Token_colon) {
                        val = this.getJsonToken();
                    } else {
                        this.Error(colon, "Expected colon");
                    }
                } else {
                    this.Error(val, "Expected string literal");
                }
            }

            const element = try this.parseJsonElement(label, val);
            if (element) |elem| {
                if (lastElement != null) {
                    lastElement.?.nextSibling = elem;
                    lastElement = elem;
                } else {
                    firstElement = elem;
                    lastElement = elem;
                }
            } else if (val.type == endtoken) {
                break;
            } else {
                this.Error(val, "Unexpected value in json");
            }

            const comma = this.getJsonToken();
            if (comma.type == endtoken) {
                break;
            } else if (comma.type != JsonTokenType.Token_comma) {
                this.Error(comma, "Unexpected token");
            }
        }
        return firstElement;
    }

    pub fn parseJsonElement(this: *@This(), label: []const u8, value: JsonToken) JsonParseError!?*JsonElement {
        var valid = true;

        var subElement: ?*JsonElement = null;

        if (value.type == JsonTokenType.Token_open_bracket) {
            subElement = try this.parseJsonList(JsonTokenType.Token_close_bracket, false);
        } else if (value.type == JsonTokenType.Token_open_brace) {
            subElement = try this.parseJsonList(JsonTokenType.Token_close_brace, true);
        } else if ((value.type == JsonTokenType.Token_string_literal) or
            (value.type == JsonTokenType.Token_true) or
            (value.type == JsonTokenType.Token_false) or
            (value.type == JsonTokenType.Token_null) or
            (value.type == JsonTokenType.Token_number))
        {} else {
            valid = false;
        }

        var result: ?*JsonElement = undefined;

        if (valid) {
            result = try this.allocator.create(JsonElement);
            result.?.label = label;
            result.?.value = value.value;
            result.?.firstSubElement = subElement;
            result.?.nextSibling = null;
        }

        return result;
    }
};

const JsonElement = struct {
    label: []const u8,
    value: []const u8,
    firstSubElement: ?*JsonElement,
    nextSibling: ?*JsonElement,
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

    const json_token = json_parser.getJsonToken();
    //print("{}\n", .{json_token});

    const result = try json_parser.parseJsonElement("", json_token);

    print("RESULT_JSON: {?}\n", .{result});
}

pub fn parseHaversinePairs(input: *std.ArrayList(u8), parsed_values: std.ArrayList(HaversinePair)) !u64 {
    var pair_count: u64 = 0;
    _ = parsed_values;
    pair_count += 1;

    const JSON = try parseJSON(input);
    std.debug.print("JSON: {}\n", .{JSON});

    const pairsArray 

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
