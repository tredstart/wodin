package client

import "../env"
import "core:bufio"
import "core:fmt"
import "core:io"
import "core:log"
import "core:net"
import "core:os"
import "core:strings"

Rows :: struct {
	size: uint,
	rows: [dynamic][]string,
}

delete_rows :: proc(r: ^Rows) {
	for row in r.rows {
		delete(row)
	}
	delete(r.rows)
}

open_request_socket :: proc(endpoint: string) -> net.TCP_Socket {
	log.info(endpoint)
	socket, err := net.dial_tcp_from_hostname_and_port_string(endpoint)
	if err != net.Dial_Error.None {
		log.errorf("Cannot dial database, %v", err)
		return -1
	}
	return socket
}

// Wraps a tcp socket with a stream.
tcp_stream :: proc(sock: net.TCP_Socket) -> (s: io.Stream) {
	s.data = rawptr(uintptr(sock))
	s.procedure = _socket_stream_proc
	return s
}

@(private)
_socket_stream_proc :: proc(
	stream_data: rawptr,
	mode: io.Stream_Mode,
	p: []byte,
	offset: i64,
	whence: io.Seek_From,
) -> (
	n: i64,
	err: io.Error,
) {
	#partial switch mode {
	case .Query:
		return io.query_utility(io.Stream_Mode_Set{.Query, .Read})
	case .Read:
		sock := net.TCP_Socket(uintptr(stream_data))
		received, recv_err := net.recv_tcp(sock, p)
		n = i64(received)

		#partial switch ex in recv_err {
		case net.TCP_Recv_Error:
			#partial switch ex {
			case .None:
				err = .None
			case .Shutdown,
			     .Not_Connected,
			     .Aborted,
			     .Connection_Closed,
			     .Host_Unreachable,
			     .Timeout:
				log.errorf("unexpected error reading tcp: %s", ex)
				err = .Unexpected_EOF
			case:
				log.errorf("unexpected error reading tcp: %s", ex)
				err = .Unknown
			}
		case nil:
			err = .None
		case:
			assert(false, "recv_tcp only returns TCP_Recv_Error or nil")
		}
	case:
		err = .Empty
	}
	return
}


client_request :: proc(r: ^Rows, e: env.Env, content: string) {
	fd := open_request_socket("localhost:4200")
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
	stream := tcp_stream(fd)
	stream_reader := io.to_reader(stream)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stream_reader)
	defer bufio.scanner_destroy(&scanner)
	reading_json := false
	for bufio.scanner_scan(&scanner) {
		line := bufio.scanner_text(&scanner)
		split := strings.split(line, ": ")
		defer delete(split)
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
			defer delete(split)
			if len(split) > 1 {
				id := 0
				counter: uint = 0
				for row in split[1:] {
					if counter == 0 {
						slice := make([]string, r.size)
						append(&r.rows, slice)
					}
					sub := strings.split(row, "\"}")
					defer delete(sub)
					r.rows[id][counter] = string(sub[0][1:])
					counter += 1
					if counter > r.size - 1 {
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
