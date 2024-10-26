package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "router"
import "server"


main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}


	router.register(.GET, "/home/hello", wait)
	router.register(.GET, "/", home)
	router.register(.GET, "/home/:keyword", deez)
	server.listen_and_serve()
}
home :: proc(req: router.Request) -> router.Response {
	return {
		status_code = 418,
		status = "I am a teapot",
		server = "wodin",
		content_type = "text/html",
		body = "<html>Hellope</html>",
		headers = {},
	}
}
deez :: proc(req: router.Request) -> router.Response {
	return {
		200,
		"OK",
		"wodin",
		"text/html",
		fmt.tprintf("<html>Redirect on %s gottem</html>", req.path_params["keyword"]),
		{},
	}
}
wait :: proc(req: router.Request) -> router.Response {
	return {
		303,
		"I am a teapot",
		"wodin",
		"text/html",
		"<html>What</html>",
		{"Location" = "/home/deeznuts", "Connection" = "close"},
	}
}
