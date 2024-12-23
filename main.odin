package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "router"
import "router/routes"
import "server"


main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	router.register(.GET, "/", routes.home)
	router.register(.GET, "/blog/list", routes.home_list)
	router.register(.GET, "/blog/:article", routes.article)
	router.register(.GET, "/login", routes.login)
	router.register(.POST, "/login", routes.login_post)
	router.register(.GET, "/create-article", routes.create_article)
	router.register(.POST, "/create-article", routes.post_article)
	router.register(.GET, "/styles", routes.styles)
	router.register(.GET, "/about", routes.about)
	router.register(.GET, "/images/:name", routes.images)
	router.register(.GET, "/favicon.ico", routes.favicon)

	server.listen_and_serve()
}
