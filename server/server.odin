package server

import "../router"
import "core:fmt"
import "core:log"
import "core:net"
import "core:os"
import "core:strings"


listen_and_serve :: proc() {
    log.info("Starting up")
	endpoint := net.Endpoint {
		address = net.IP4_Loopback,
		port    = 6969,
	}

	tcp_socket, tcp_err := net.listen_tcp(endpoint)
	if tcp_err != net.Listen_Error.None {
		log.errorf("Cannot listen: exiting with status %d", tcp_err)
		return
	}

	for {
		client, source, net_err := net.accept_tcp(tcp_socket)
		defer net.close(client)

		if tcp_err != net.Accept_Error.None {
			log.errorf("Cannot accept: exiting with status %d", net_err)
			return
		}

		buf := make([]byte, 1024)
		defer delete(buf)

		_, error := os.read(os.Handle(client), buf)
		if error != os.ERROR_NONE {
			log.error("Error while reading sock")
			continue
		}
		req, ok := router.parse_request(buf).?
		if !ok {
			os.write_string(
				os.Handle(client),
				router.respond(
					{400, "Bad request", "wodin", "text/html", "<html>Bad request</html>", {}},
				),
			)
			continue
		}

		resp := router.request_handler(&req)
		os.write_string(os.Handle(client), resp)
	}
}
