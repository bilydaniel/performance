const std = @import("std");
const Profiler = @import("profiler.zig");

const print = std.debug.print;

pub const Pair = struct {
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
    source: []u8,
    at: u64 = 0,
    hadError: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: []u8) !JsonParser {
        return JsonParser{
            .allocator = allocator,
            .source = input,
            .at = 0,
            .hadError = false,
        };
    }

    fn parseKeyword(this: *JsonParser, rest: []const u8, result: *JsonToken, tokentype: JsonTokenType) void {
        const tokenstart = this.at;
        this.at += 1;

        if (rest.len <= this.source.len - this.at) {
            const check = this.source[this.at .. this.at + rest.len];
            if (std.mem.eql(u8, check, rest)) {
                this.at += rest.len;
                const tokenend = this.at;

                result.type = tokentype;
                result.value = this.source[tokenstart..tokenend];
            }
        }
    }

    fn isJsonDigit(this: *JsonParser) bool {
        var result = false;

        if (this.at < this.source.len) {
            const val = this.source[this.at];
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

        if (this.at < this.source.len) {
            const val = this.source[this.at];
            switch (val) {
                '{' => {
                    result.type = JsonTokenType.Token_open_brace;
                    this.at += 1;
                },
                '}' => {
                    result.type = JsonTokenType.Token_close_brace;
                    this.at += 1;
                },
                '[' => {
                    result.type = JsonTokenType.Token_open_bracket;
                    this.at += 1;
                },
                ']' => {
                    result.type = JsonTokenType.Token_close_bracket;
                    this.at += 1;
                },
                ',' => {
                    result.type = JsonTokenType.Token_comma;
                    this.at += 1;
                },
                ':' => {
                    result.type = JsonTokenType.Token_colon;
                    this.at += 1;
                },
                ';' => {
                    result.type = JsonTokenType.Token_semi_colon;
                    this.at += 1;
                },

                'f' => {
                    //TODO: doesent return error, @fix
                    this.parseKeyword("alse", &result, JsonTokenType.Token_false);
                },
                't' => {
                    this.parseKeyword("rue", &result, JsonTokenType.Token_true);
                },
                'n' => {
                    this.parseKeyword("ull", &result, JsonTokenType.Token_null);
                },

                '"' => {
                    this.at += 1;
                    result.type = JsonTokenType.Token_string_literal;
                    const stringstart = this.at;

                    while (this.at < this.source.len and this.source[this.at] != '"') {
                        if ((this.at + 1 < this.source.len) and this.source[this.at] == '\\' and this.source[this.at + 1] == '"') {
                            this.at += 1;
                        }
                        this.at += 1;
                    }

                    const stringend = this.at;
                    result.value = this.source[stringstart..stringend];

                    if (this.at < this.source.len) {
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

                    if (val == '0') {
                        this.at += 1;
                    }

                    if (val != '0') {
                        while (this.isJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    if (this.at < this.source.len and this.source[this.at] == '.') {
                        this.at += 1;
                        while (this.isJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    if (this.at < this.source.len and (this.source[this.at] == 'e' or this.source[this.at] == 'E')) {
                        this.at += 1;

                        if (this.at < this.source.len and (this.source[this.at] == '+' or this.source[this.at] == '-')) {
                            this.at += 1;
                        }

                        while (this.isJsonDigit()) {
                            this.at += 1;
                        }
                    }

                    const numberend = this.at;
                    result.value = this.source[numberstart..numberend];
                },
                else => result.type = JsonTokenType.Token_error,
            }
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

    pub fn inBounds(this: *@This()) bool {
        return (this.at < this.source.len);
    }

    pub fn isParsing(this: *@This()) bool {
        return (!this.hadError and this.inBounds());
    }

    //TODO: make the error handling more zig?
    pub fn Error(this: *@This(), token: JsonToken, msg: []const u8) void {
        this.hadError = true;
        std.debug.print("ERROR: parser: {}, token:{}, msg:{s}\n", .{ this.at, token, msg });
    }

    pub fn parseJsonList(this: *@This(), endtoken: JsonTokenType, hasLabel: bool) JsonParseError!?*JsonElement {
        var firstElement: ?*JsonElement = null;
        var lastElement: ?*JsonElement = null;
        var label: []const u8 = "";

        while (this.isParsing()) {
            var val = this.getJsonToken();
            if (hasLabel) {
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

fn parseJSON(input: []u8, allocator: std.mem.Allocator) !?*JsonElement {
    var json_parser = try JsonParser.init(allocator, input);

    const json_token = json_parser.getJsonToken();

    const result = try json_parser.parseJsonElement("", json_token);

    return result;
}

pub fn lookupElement(JSON: ?*JsonElement, name: []const u8) ?*JsonElement {
    var result: ?*JsonElement = null;

    if (JSON) |json| {
        var search = json.firstSubElement;
        while (search) |element| {
            if (std.mem.eql(u8, element.label, name)) {
                result = element;
                break;
            }
            search = element.nextSibling;
        }
    }
    return result;
}

pub fn convertSign(source: []const u8, at: *u64) f64 {
    var result: f64 = 1.0;

    if (at.* < source.len and source[at.*] == '-') {
        result = -1.0;
        at.* += 1;
    }
    return result;
}

pub fn convertNumber(source: []const u8, at: *u64) f64 {
    var result: f64 = 0.0;

    while (at.* < source.len) {
        const char = source[at.*];
        if (char == '.' or char == 'e') {
            break;
        }
        const val = source[at.*] - @as(u8, '0');
        //breaks if . or e
        if (val < 10) {
            result = 10.0 * result + @as(f64, @floatFromInt(val));
            at.* += 1;
        } else {
            break;
        }
    }
    return result;
}

pub fn convertElementToF64(element: *JsonElement, name: []const u8) f64 {
    var result: f64 = 0;

    const innerElement = lookupElement(element, name);

    if (innerElement) |inn| {
        const source = inn.value;
        var at: u64 = 0;

        const sign: f64 = convertSign(source, &at);
        var number: f64 = convertNumber(source, &at);

        if (at < source.len and source[at] == '.') {
            at += 1;
            var C: f64 = 1.0 / 10.0;
            while (at < source.len) {
                const char = source[at];
                if (char == '.' or char == 'e') {
                    break;
                }
                const val = source[at] - @as(u8, '0');
                //breaks if . or e
                if (val < 10) {
                    number = number + C * @as(f64, @floatFromInt(char - '0'));
                    C *= 1.0 / 10.0;
                    at += 1;
                } else {
                    break;
                }
            }
        }

        if (at < source.len and (source[at] == 'e' or source[at] == 'E')) {
            at += 1;

            if (at < source.len and source[at] == '+') {
                at += 1;
            }

            const Esign = convertSign(source, &at);
            const Enumber = convertNumber(source, &at);
            const E = Esign * Enumber;
            number *= std.math.pow(f64, 10, E);
        }

        result = sign * number;
    }
    return result;
}

pub fn parseHaversinePairs(allocator: std.mem.Allocator, input: []u8, parsed_values: *std.ArrayList(Pair)) !u64 {
    var pair_count: u64 = 0;

    const JSON = try parseJSON(input, allocator);

    const pairsArray = lookupElement(JSON, "pairs");
    if (pairsArray) |pairs| {
        var element = pairs.firstSubElement;
        while (element) |e| : (element = e.nextSibling) {
            pair_count += 1;
            const pair = Pair{
                .x0 = convertElementToF64(e, "x0"),
                .y0 = convertElementToF64(e, "y0"),
                .x1 = convertElementToF64(e, "x1"),
                .y1 = convertElementToF64(e, "y1"),
            };

            try parsed_values.append(allocator, pair);
        }
    }

    freeJson(JSON, allocator);

    return pair_count;
}

pub fn freeJson(JSON: ?*JsonElement, allocator: std.mem.Allocator) void {
    var json = JSON;
    while (json) |j| {
        json = j.nextSibling;

        freeJson(j.firstSubElement, allocator);
        allocator.destroy(j);
    }
}
