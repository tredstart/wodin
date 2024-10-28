package server

import "../router"
import "../utils"
import "core:fmt"
import "core:log"
import "core:net"
import "core:os"
import "core:strconv"
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

		req := router.Request{}
		buf := [1024]byte{}
		os.read(os.Handle(client), buf[:])
		line := string(buf[:])
		split := strings.split(line, "\r\n\r\n")
		defer delete(split)
		lines := strings.split(split[0], "\r\n")
		sum := len(split[0])
		for line, i in lines {
			if i == 0 {
				l := strings.split(line, " ")
				defer delete(l)
				if len(l) != 3 {
					os.write_string(
						os.Handle(client),
						router.respond(
							{
								400,
								"Bad request",
								"wodin",
								"text/html",
								"<html>Bad request</html>",
								{},
							},
						),
					)
					continue
				}
				req.method = l[0]
				req.path = l[1]
				req.version = l[2]
			} else {
				router.parse_request(&req, line)
			}
		}
		cl, ok := req.headers["Content-Length"]
		if ok {
			l := strconv.atoi(cl)
			if l > len(split[1]) {
				content := make([]byte, l)
				copy(content, transmute([]byte)split[1])
				_, err := os.read(os.Handle(client), content[len(split[1]):])
				if err != os.ERROR_NONE {
					os.write_string(
						os.Handle(client),
						router.respond(
							{400, "Bad request", "wodin", "text/html", fmt.tprintf("%v", err), {}},
						),
					)
					continue
				}
				log.info(string(content))
				router.parse_request(&req, string(content))
			} else {
				log.info(split[1])
				router.parse_request(&req, split[1])
			}
		}

		log.info(req)

		resp := router.request_handler(&req)
		os.write_string(os.Handle(client), resp)
	}
}
