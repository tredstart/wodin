package main

import "core:fmt"
import "core:log"
import "core:net"
import "core:os"

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)
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

		data, error := os.read(os.Handle(client), buf)
		if error != os.ERROR_NONE {
			log.error("Error while reading sock")
		} else {
			for char in buf {
				fmt.printf("%c", char)
			}
		}

		resp := respond({418, "I am a teapot", "wodin", "text/html", "<html>Hello world!</html>"})
		os.write_string(os.Handle(client), resp)

	}
}

Response :: struct {
	status_code:  u32,
	status:       string,
	server:       string,
	content_type: string,
	body:         string,
}

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
