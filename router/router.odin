package router

import "core:fmt"
import "core:log"
import "core:strings"

Response :: struct {
	status_code:  u32,
	status:       string,
	server:       string,
	content_type: string,
	body:         string,
}

Request :: struct {
	method:         string,
	version:        string,
	path:           string,
	connection:     string,
	content_length: string,
	headers:        map[string]string,
}

Route :: struct {
	dyn:      bool,
	method:   string,
	path:     string,
	call:     Maybe(proc(_: Request)),
	children: TreeElements,
}

TreeElements :: map[string]^Route

route_tree := TreeElements{}

respond :: proc(res: Response) -> string {
	return fmt.tprintf(
		"HTTP/1.1 %d %s\r\nServer: %s\r\nContent-type: %s\r\n\r\n%s\r\n",
		res.status_code,
		res.status,
		res.server,
		res.content_type,
		res.body,
	)
}

parse_request :: proc(req_string: []byte) -> Maybe(Request) {
	request := string(req_string)
	lines := strings.split(request, "\r\n")
	req := Request{}
	for line, i in lines {
		switch i {
		case 0:
			l := strings.split(lines[i], " ")
			if len(l) != 3 {
				log.error("Cannot parse request")
				return nil
			}
			req.method = l[0]
			req.path = l[1]
			req.version = l[2]
		case:
			l := strings.split(lines[i], ":")
			if l[0] == "Content-Length" {
				req.content_length = l[1]
				continue
			}
			if l[0] == "Connection" {
				req.connection = l[1]
				continue
			}
			if len(l) > 1 {
				req.headers[l[0]] = l[1]
			}
		}
	}
	log.info(req)
	return req
}

new_route :: proc(p, method: string, call: proc(_: Request)) {
	req := new(Route)
	req.method = method
	req.path = p
	req.call = call
	route_tree[p] = req
}

home :: proc(r: Request) {
	// do something
	respond({})
}


walk_routes :: proc(
	tree: ^map[string]^Route,
	method, path: string,
	full_path: []string,
	i: int,
	call: proc(_: Request),
) {
	fmt.eprintln(path)
	route: ^Route
	if path not_in tree {
		route = new(Route)
		route.path = path
		tree[path] = route
	} else {
		route = tree[path]
	}
	fmt.eprintln(tree)
	if i == len(full_path) - 1 {
		route.call = call
		route.method = method
		return
	} else {
		walk_routes(&route.children, method, full_path[i + 1], full_path, i + 1, call)
	}
}


read_routes :: proc(
	tree: ^map[string]^Route,
	method, path: string,
	full_path: []string,
	i: int,
	call: proc(_: Request),
) {
	fmt.eprintln(path)
	route: ^Route
	if path not_in tree {
		route = new(Route)
		route.path = path
		tree[path] = route
	} else {
		route = tree[path]
	}
	fmt.eprintln(tree)
	if i == len(full_path) - 1 {
		route.call = call
		route.method = method
		return
	} else {
		walk_routes(&route.children, method, full_path[i + 1], full_path, i + 1, call)
	}
}

register :: proc(method, path: string, call: proc(_: Request)) {
	full_path := strings.split(path, "/")
	walk_routes(&route_tree, method, full_path[0], full_path, 0, call)
}

request_handler :: proc(req: Request) {
	//
	// full_path := strings.split(path, "/")
	// walk_routes(&route_tree, method, full_path[0], full_path, 0, call)
}
