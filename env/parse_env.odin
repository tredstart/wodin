package env

import "core:log"
import "core:os"
import "core:strings"

Env :: struct {
	pass:    string,
	db_addr: string,
	db_key:  string,
}

parse_env :: proc(filename: string) -> Maybe(Env) {
	data, ok := os.read_entire_file_from_filename(filename)
	defer delete(data)
	if !ok {
		log.error("Could not read env file")
		return nil
	}
	lines := string(data)
	env := Env{}
	for line in strings.split(lines, "\n") {
		l := strings.split(line, "=")
		defer delete(l)
		if l[0] == "PASS" {
			env.pass = l[1]
		}
		if l[0] == "URL" {
			env.db_addr = l[1]
		}
		if l[0] == "TOKEN" {
			env.db_key = l[1]
		}
	}
	return env
}
