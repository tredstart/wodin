package client

import "core:log"
import "core:net"
import "core:os"

request :: proc(endpoint: string) -> net.TCP_Socket {
	log.info(endpoint)
	socket, err := net.dial_tcp_from_hostname_and_port_string(endpoint)
	if err != net.Dial_Error.None {
		log.errorf("Cannot dial database, %v", err)
		return -1
	}
	return socket
}
