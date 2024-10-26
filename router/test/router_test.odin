package test

import "../../router"
import "core:fmt"
import "core:testing"

test_route_handler :: proc(req: router.Request) -> router.Response {
	return {"home"}
}
test_post_handler :: proc(req: router.Request) -> router.Response {
	return {"post"}
}

@(test)
test_routes :: proc(t: ^testing.T) {
	router.register(.GET, "/home", test_route_handler)
	router.register(.POST, "/post", test_route_handler)
	assert(router.request_handler({method = "GET", path = "/home"}) == "home")
	assert(router.request_handler({method = "POST", path = "/home"}) != "home")
}
