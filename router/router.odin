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
	headers:      map[string]string,
}

Request :: struct {
	method:      string,
	version:     string,
	path:        string,
	form_data:   map[string]string,
	headers:     map[string]string,
	path_params: map[string]string,
}

HttpMethod :: enum {
	GET,
	POST,
	LENGTH,
}

string_to_method :: proc(m: string) -> HttpMethod {
	if m == "GET" {
		return .GET
	}
	if m == "POST" {
		return .POST
	}
	return .LENGTH
}

Route :: struct {
	dyn:      bool,
	method:   HttpMethod,
	path:     string,
	call:     Maybe(proc(_: Request) -> Response),
	children: [HttpMethod.LENGTH]TreeElements,
}

TreeElements :: map[string]^Route

route_tree := TreeElements{}

respond :: proc(res: Response) -> string {
	headers: string
	for key, value in res.headers {
		headers = fmt.tprintf("%s\r\n%s: %s", headers, key, value)
	}
	return fmt.tprintf(
		"HTTP/1.1 %d %s%s\r\nServer: %s\r\nContent-type: %s\r\n\r\n%s\r\n",
		res.status_code,
		res.status,
		headers,
		res.server,
		res.content_type,
		res.body,
	)
}

parse_request :: proc(req: ^Request, line: string) {
	l := strings.split(line, ": ")
	defer delete(l)
	if len(l) > 1 {
		req.headers[l[0]] = l[1]
	} else {
		form := strings.split(line, "&")
		defer delete(form)
		for pair in form {
			kv := strings.split(pair, "=")
			defer delete(kv)
			if len(kv) > 1 {
				sp := strings.split(kv[1], "\x00")
				defer delete(sp)
				req.form_data[kv[0]] = sp[0]
			}
		}
	}
}

walk_routes :: proc(
	tree: ^map[string]^Route,
	method: HttpMethod,
	path: string,
	full_path: []string,
	i: int,
	call: proc(_: Request) -> Response,
) {
	route: ^Route
	p := path
	dyn := false
	if len(path) > 1 && path[0] == ':' {
		p = string(path[1:])
		dyn = true
	}
	if p not_in tree {
		route = new(Route)
		route.dyn = dyn
		route.path = p
		tree[p] = route
	} else {
		route = tree[p]
	}
	if i == len(full_path) - 1 {
		route.call = call
		route.method = method
		return
	} else {
		walk_routes(&route.children[method], method, full_path[i + 1], full_path, i + 1, call)
	}
}

read_routes :: proc(
	tree: map[string]^Route,
	method: HttpMethod,
	path: string,
	full_path: []string,
	i: int,
	req: ^Request,
) -> Response {
	route, ok := tree[path]
	if !ok {
		for _, node in tree {
			if node.dyn {
				req.path_params[node.path] = path
				resp := read_routes(tree, method, node.path, full_path, i + 1, req)
				if resp.status_code != 404 {
					return resp
				}
				delete_key(&req.path_params, node.path)
			}
		}
		return {404, "Not found", "wodin", "text/html", "<html>Page not found</html>", {}}
	} else {
		if i >= len(full_path) - 1 {
			call, ok := route.call.?
			if !ok {
				return {404, "Not found", "wodin", "text/html", "<html>Page not found</html>", {}}
			}

			resp := call(req^)
			return resp
		} else {
			if method >= HttpMethod.LENGTH {
				return {405, "Method not allowed", "wodin", "text/html", "<html>Method not allowed</html>", {}}
			}
			return read_routes(
				route.children[method],
				method,
				full_path[i + 1],
				full_path,
				i + 1,
				req,
			)
		}
	}
}

register :: proc(method: HttpMethod, path: string, call: proc(_: Request) -> Response) {
	full_path := strings.split(path, "/")
	defer delete(full_path)
	walk_routes(&route_tree, method, full_path[0], full_path, 0, call)
}

request_handler :: proc(req: ^Request) -> string {
	full_path := strings.split(req.path, "/")
	defer delete(full_path)
	response := read_routes(
		route_tree,
		string_to_method(req.method),
		full_path[0],
		full_path,
		0,
		req,
	)
	when ODIN_DEBUG {
		log.warn(response)
	}
	return respond(response)
}
