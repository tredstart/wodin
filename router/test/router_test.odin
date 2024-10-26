package test

import "../../router"
import "core:fmt"
import "core:strings"
import "core:testing"

test_route_handler :: proc(req: router.Request) -> router.Response {
	return {body = "home"}
}
test_article_handler :: proc(req: router.Request) -> router.Response {
	return {body = req.path_params["article"]}
}
test_id_handler :: proc(req: router.Request) -> router.Response {
	return {body = req.path_params["id"]}
}

@(test)
test_routes :: proc(t: ^testing.T) {
	router.register(.GET, "/home", test_route_handler)
	router.register(.GET, "/home/:article", test_article_handler)
	router.register(.GET, "/home/:id/profile", test_id_handler)
	resp := router.request_handler(&{method = "GET", path = "/home"})
	resp = strings.split(resp, "\r\n\r\n")[1]
	assert(string(resp[:len(resp) - 2]) == "home")
	resp = router.request_handler(&{method = "GET", path = "/home/deeznuts"})
	resp = strings.split(resp, "\r\n\r\n")[1]
	assert(string(resp[:len(resp) - 2]) == "deeznuts")
	resp = router.request_handler(&{method = "GET", path = "/home/69420/profile"})
	resp = strings.split(resp, "\r\n\r\n")[1]
	assert(string(resp[:len(resp) - 2]) == "69420")
}
