package haversine

import "core:fmt"
import "core:math"
import "core:mem"

Pair :: struct {
	x0, y0, x1, y1: f64,
}

Json_Token_Type :: enum {
	End_Of_Stream,
	Error,
	Open_Brace,
	Open_Bracket,
	Close_Brace,
	Close_Bracket,
	Comma,
	Colon,
	Semi_Colon,
	String_Literal,
	Number,
	True,
	False,
	Null,
}

Json_Token :: struct {
	type:  Json_Token_Type,
	value: string,
}

Json_Element :: struct {
	label:             string,
	value:             string,
	first_sub_element: ^Json_Element,
	next_sibling:      ^Json_Element,
}

Json_Parser :: struct {
	source:    []u8,
	at:        u64,
	had_error: bool,
}

json_parser_init :: proc(input: []u8) -> Json_Parser {
	return Json_Parser{source = input, at = 0, had_error = false}
}

// --- token scanning -------------------------------------------------------

parse_keyword :: proc(
	p: ^Json_Parser,
	rest: string,
	result: ^Json_Token,
	token_type: Json_Token_Type,
) {
	token_start := p.at
	p.at += 1

	if u64(len(rest)) <= u64(len(p.source)) - p.at {
		check := p.source[p.at:p.at + u64(len(rest))]
		if string(check) == rest {
			p.at += u64(len(rest))
			token_end := p.at

			result.type = token_type
			result.value = string(p.source[token_start:token_end])
		}
	}
}

is_json_digit :: proc(p: ^Json_Parser) -> bool {
	result := false

	if p.at < u64(len(p.source)) {
		val := p.source[p.at]
		result = val >= '0' && val <= '9'
	}

	return result
}

is_white_space :: proc(p: Json_Parser) -> bool {
	if p.at >= u64(len(p.source)) {
		return false
	}

	val := p.source[p.at]
	return val == ' ' || val == '\t' || val == '\n' || val == '\r'
}

get_json_token :: proc(p: ^Json_Parser) -> Json_Token {
	result: Json_Token
	result.value = ""

	for is_white_space(p^) {
		p.at += 1
	}

	if p.at < u64(len(p.source)) {
		val := p.source[p.at]
		switch val {
		case '{':
			result.type = .Open_Brace
			p.at += 1
		case '}':
			result.type = .Close_Brace
			p.at += 1
		case '[':
			result.type = .Open_Bracket
			p.at += 1
		case ']':
			result.type = .Close_Bracket
			p.at += 1
		case ',':
			result.type = .Comma
			p.at += 1
		case ':':
			result.type = .Colon
			p.at += 1
		case ';':
			result.type = .Semi_Colon
			p.at += 1

		case 'f':
			// TODO: doesn't return error, @fix
			parse_keyword(p, "alse", &result, .False)
		case 't':
			parse_keyword(p, "rue", &result, .True)
		case 'n':
			parse_keyword(p, "ull", &result, .Null)

		case '"':
			p.at += 1
			result.type = .String_Literal
			string_start := p.at

			for p.at < u64(len(p.source)) && p.source[p.at] != '"' {
				if p.at + 1 < u64(len(p.source)) &&
				   p.source[p.at] == '\\' &&
				   p.source[p.at + 1] == '"' {
					p.at += 1
				}
				p.at += 1
			}

			string_end := p.at
			result.value = string(p.source[string_start:string_end])

			if p.at < u64(len(p.source)) {
				p.at += 1
			}

		case '-', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			result.type = .Number
			number_start := p.at

			if val == '-' {
				p.at += 1
			}

			if val == '0' {
				p.at += 1
			}

			if val != '0' {
				for is_json_digit(p) {
					p.at += 1
				}
			}

			if p.at < u64(len(p.source)) && p.source[p.at] == '.' {
				p.at += 1
				for is_json_digit(p) {
					p.at += 1
				}
			}

			if p.at < u64(len(p.source)) && (p.source[p.at] == 'e' || p.source[p.at] == 'E') {
				p.at += 1

				if p.at < u64(len(p.source)) && (p.source[p.at] == '+' || p.source[p.at] == '-') {
					p.at += 1
				}

				for is_json_digit(p) {
					p.at += 1
				}
			}

			number_end := p.at
			result.value = string(p.source[number_start:number_end])

		case:
			result.type = .Error
		}
	}

	return result
}

in_bounds :: proc(p: ^Json_Parser) -> bool {
	return p.at < u64(len(p.source))
}

is_parsing :: proc(p: ^Json_Parser) -> bool {
	return !p.had_error && in_bounds(p)
}

// TODO: make the error handling more Odin-idiomatic?
json_error :: proc(p: ^Json_Parser, token: Json_Token, msg: string) {
	p.had_error = true
	fmt.printf("ERROR: parser: %v, token:%v, msg:%s\n", p.at, token, msg)
}

// --- tree building ----------------------------------------------------------

parse_json_list :: proc(
	p: ^Json_Parser,
	end_token: Json_Token_Type,
	has_label: bool,
) -> (
	^Json_Element,
	mem.Allocator_Error,
) {
	first_element: ^Json_Element = nil
	last_element: ^Json_Element = nil
	label: string = ""

	for is_parsing(p) {
		val := get_json_token(p)
		if has_label {
			if val.type == .String_Literal {
				label = val.value
				colon := get_json_token(p)
				if colon.type == .Colon {
					val = get_json_token(p)
				} else {
					json_error(p, colon, "Expected colon")
				}
			} else {
				json_error(p, val, "Expected string literal")
			}
		}

		element, err := parse_json_element(p, label, val)
		if err != .None {
			return nil, err
		}

		if element != nil {
			if last_element != nil {
				last_element.next_sibling = element
				last_element = element
			} else {
				first_element = element
				last_element = element
			}
		} else if val.type == end_token {
			break
		} else {
			json_error(p, val, "Unexpected value in json")
		}

		comma := get_json_token(p)
		if comma.type == end_token {
			break
		} else if comma.type != .Comma {
			json_error(p, comma, "Unexpected token")
		}
	}

	return first_element, .None
}

parse_json_element :: proc(
	p: ^Json_Parser,
	label: string,
	value: Json_Token,
) -> (
	^Json_Element,
	mem.Allocator_Error,
) {
	valid := true
	sub_element: ^Json_Element = nil

	if value.type == .Open_Bracket {
		elem, err := parse_json_list(p, .Close_Bracket, false)
		if err != .None {
			return nil, err
		}
		sub_element = elem
	} else if value.type == .Open_Brace {
		elem, err := parse_json_list(p, .Close_Brace, true)
		if err != .None {
			return nil, err
		}
		sub_element = elem
	} else if value.type == .String_Literal ||
	   value.type == .True ||
	   value.type == .False ||
	   value.type == .Null ||
	   value.type == .Number {
		// leaf value, nothing extra to do
	} else {
		valid = false
	}

	result: ^Json_Element = nil

	if valid {
		new_elem, err := new(Json_Element)
		if err != .None {
			return nil, err
		}
		new_elem.label = label
		new_elem.value = value.value
		new_elem.first_sub_element = sub_element
		new_elem.next_sibling = nil
		result = new_elem
	}

	return result, .None
}

parse_json :: proc(input: []u8) -> (^Json_Element, mem.Allocator_Error) {
	json_parser := json_parser_init(input)

	json_token := get_json_token(&json_parser)

	result, err := parse_json_element(&json_parser, "", json_token)
	return result, err
}

lookup_element :: proc(json: ^Json_Element, name: string) -> ^Json_Element {
	result: ^Json_Element = nil

	if json != nil {
		search := json.first_sub_element
		for search != nil {
			if search.label == name {
				result = search
				break
			}
			search = search.next_sibling
		}
	}

	return result
}

convert_sign :: proc(source: string, at: ^u64) -> f64 {
	result: f64 = 1.0

	if at^ < u64(len(source)) && source[at^] == '-' {
		result = -1.0
		at^ += 1
	}

	return result
}

convert_number :: proc(source: string, at: ^u64) -> f64 {
	result: f64 = 0.0

	for at^ < u64(len(source)) {
		char := source[at^]
		if char == '.' || char == 'e' {
			break
		}
		val := source[at^] - '0'
		// breaks if . or e
		if val < 10 {
			result = 10.0 * result + f64(val)
			at^ += 1
		} else {
			break
		}
	}

	return result
}

convert_element_to_f64 :: proc(element: ^Json_Element, name: string) -> f64 {
	result: f64 = 0

	inner_element := lookup_element(element, name)

	if inner_element != nil {
		source := inner_element.value
		at: u64 = 0

		sign := convert_sign(source, &at)
		number := convert_number(source, &at)

		if at < u64(len(source)) && source[at] == '.' {
			at += 1
			c: f64 = 1.0 / 10.0
			for at < u64(len(source)) {
				char := source[at]
				if char == '.' || char == 'e' {
					break
				}
				val := source[at] - '0'
				// breaks if . or e
				if val < 10 {
					number = number + c * f64(char - '0')
					c *= 1.0 / 10.0
					at += 1
				} else {
					break
				}
			}
		}

		if at < u64(len(source)) && (source[at] == 'e' || source[at] == 'E') {
			at += 1

			if at < u64(len(source)) && source[at] == '+' {
				at += 1
			}

			e_sign := convert_sign(source, &at)
			e_number := convert_number(source, &at)
			e := e_sign * e_number
			number *= math.pow_f64(10, e)
		}

		result = sign * number
	}

	return result
}

parse_haversine_pairs :: proc(input: []u8, parsed_values: ^[dynamic]Pair) -> (u64, bool) {
	pair_count: u64 = 0

	json, err := parse_json(input)
	if err != .None {
		return 0, err == nil
	}

	pairs_array := lookup_element(json, "pairs")
	if pairs_array != nil {
		element := pairs_array.first_sub_element
		for element != nil {
			pair_count += 1
			pair := Pair {
				x0 = convert_element_to_f64(element, "x0"),
				y0 = convert_element_to_f64(element, "y0"),
				x1 = convert_element_to_f64(element, "x1"),
				y1 = convert_element_to_f64(element, "y1"),
			}

			append(parsed_values, pair)

			element = element.next_sibling
		}
	}

	free_json(json)

	return pair_count, true
}

free_json :: proc(json: ^Json_Element) {
	j := json
	for j != nil {
		next := j.next_sibling

		free_json(j.first_sub_element)
		free(j)

		j = next
	}
}
