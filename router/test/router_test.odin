package test

import "../../router"
import "core:fmt"
import "core:testing"

test_route_handler :: proc(req: router.Request) {

}

@(test)
test_routes :: proc(t: ^testing.T) {
	router.register("get", "/home", test_route_handler)

	assert(router.route_tree[""].method != "get")
	assert(router.route_tree[""].children["home"].method == "get")
	assert(router.route_tree[""].children["home"].call == test_route_handler)
}
