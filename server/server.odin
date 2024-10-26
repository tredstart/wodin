package server

import "core:fmt"
import "core:log"
import "core:net"
import "core:os"
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
	host:           string,
	connection:     string,
	content_length: string,
	headers:        map[string]string,
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
			if l[0] == "Host" {
				req.host = l[1]
				continue
			}
			if l[0] == "Content-Length" {
				req.content_length = l[1]
				continue
			}
			if l[0] == "Connection" {
				req.connection = l[1]
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

listen_and_serve :: proc() {
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
		req, ok := parse_request(buf).?
		if !ok {
			os.write_string(
				os.Handle(client),
				respond({400, "Bad request", "wodin", "text/html", "<html>Bad request</html>"}),
			)
			continue
		}

		/// TODO: handle_request()
		resp := respond({418, "I am a teapot", "wodin", "text/html", "<html>Hello world!</html>"})
		os.write_string(os.Handle(client), resp)
	}
}
