package client

import "../env"
import "../utils"
import "core:bufio"
import "core:fmt"
import "core:io"
import "core:log"
import "core:net"
import "core:os"
import "core:strings"

Rows :: [dynamic][3]string

open_request_socket :: proc(endpoint: string) -> net.TCP_Socket {
	log.info(endpoint)
	socket, err := net.dial_tcp_from_hostname_and_port_string(endpoint)
	if err != net.Dial_Error.None {
		log.errorf("Cannot dial database, %v", err)
		return -1
	}
	return socket
}

client_request :: proc(r: ^Rows, e: env.Env, content: string) {
	fd := open_request_socket("database:4200")
	defer net.close(fd)
	cl := len(content)
	req := fmt.tprintf(
		"POST /v2/pipeline HTTP/1.1\r\n" +
		"Host: %s\r\n" +
		"User-Agent: wodin\r\n" +
		"Authorization: Bearer %s\r\n" +
		"Content-Type: application/json\r\n" +
		"Accept: application/json\r\n" +
		"Content-Length: %d\r\n" +
		"\r\n" +
		"%s",
		e.db_addr,
		e.db_key,
		cl,
		content,
	)
	os.write_string(os.Handle(fd), req)
	stream := utils.tcp_stream(fd)
	stream_reader := io.to_reader(stream)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stream_reader)
	reading_json := false
	for bufio.scanner_scan(&scanner) {
		line := bufio.scanner_text(&scanner)
		split := strings.split(line, ": ")
		if len(split) > 1 {
			if split[0] == "status" && split[1] == "200" {
				reading_json = true
				continue
			}
		}
		if line == "END" {
			break
		}
		if reading_json {
			split := strings.split(line, "value\":")
			if len(split) > 1 {
				id := 0
				counter: uint = 0
				for row in split[1:] {
					if counter == 0 {
						append(r, [3]string{})
					}
					sub := strings.split(row, "\"}")
					r[id][counter] = string(sub[0][1:])
					counter += 1
					if counter > 2 {
						id += 1
						counter = 0
					}
				}
			} else {
				log.warn("something wrong with the response")
				log.warn(split)
			}
		}
	}

	if err := bufio.scanner_error(&scanner); err != nil {
		log.error("Scanner error:", err)
		return
	}
}
