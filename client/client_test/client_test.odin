package client_test

import "../../client"
import "../../env"
import "../../openssl"
import "core:bufio"
import "core:c"
import "core:fmt"
import "core:io"
import "core:log"
import "core:net"
import "core:os"
import "core:strings"
import "core:testing"

SSL_Error :: enum {
	Ok,
	Controlled_Shutdown,
	Fatal_Shutdown,
	SSL_Write_Failed,
}

Error :: union #shared_nil {
	net.Dial_Error,
	net.Parse_Endpoint_Error,
	net.Network_Error,
	SSL_Error,
}

@(test)
test_database_request :: proc(t: ^testing.T) {
	e, ok := env.parse_env("test.env").?
	assert(ok)
	assert(e.db_key != "" && e.db_addr != "")
	fd := client.request(e.db_addr)
	defer net.close(fd)
	log.warn(fd)
	content := "{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"SELECT * FROM articles\"}},{\"type\":\"close\"}]}"
	cl := len(content)
	req := fmt.tprintf(
		"GET /v2/pipeline HTTP/2\r\n" +
		"Host: testenvblog-tredstart.turso.io\r\n" +
		"User-Agent: wodin\r\n" +
		"Authorization: Bearer %s\r\n" +
		"Content-Type: application/json\r\n" +
		"Accept: application/json\r\n" +
		"Content-Length: %d\r\n" +
		"\r\n" +
		"%s",
		e.db_key,
		cl,
		content,
	)
	log.warn(req)

	ctx := openssl.SSL_CTX_new(openssl.TLS_client_method())
	log.warn(ctx)
	ssl := openssl.SSL_new(ctx)
	log.warn(ssl)
	openssl.SSL_set_fd(ssl, c.int(fd))

	hostname := strings.split(e.db_addr, ":")
	log.warn(hostname)
	chostname := strings.clone_to_cstring(hostname[0])
	log.warn(chostname)
	defer delete(chostname)
	openssl.SSL_set_tlsext_host_name(ssl, chostname)


	err: SSL_Error
	switch openssl.SSL_connect(ssl) {
	case 2:
		err = SSL_Error.Controlled_Shutdown
	case 1: // success
	case:
		err = SSL_Error.Fatal_Shutdown
	}
	log.error(err)
	buf := transmute([]byte)req
	for cl > 0 {
		ret := openssl.SSL_write(ssl, raw_data(buf), c.int(cl))
		log.error(ret)
		if ret <= 0 {
			err := SSL_Error.SSL_Write_Failed
			log.error(err)
		}
		cl -= int(ret)
	}
	parse_response(fd, ssl)
}

ssl_tcp_stream :: proc(sock: ^openssl.SSL) -> (s: io.Stream) {
	s.data = sock
	s.procedure = _ssl_stream_proc
	return s
}

@(private)
_ssl_stream_proc :: proc(
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
		ssl := cast(^openssl.SSL)stream_data
		ret := openssl.SSL_read(ssl, raw_data(p), c.int(len(p)))
		if ret <= 0 {
			return 0, .Unexpected_EOF
		}

		return i64(ret), nil
	case:
		err = .Empty
	}
	return
}

parse_response :: proc(socket: net.TCP_Socket, ssl: ^openssl.SSL) {
	stream: io.Stream
	stream = ssl_tcp_stream(ssl)
	data := ([^]u8)(stream.data)
	stream_reader := io.to_reader(stream)
	log.warn(stream_reader)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stream_reader)
	// Read all lines
	for bufio.scanner_scan(&scanner) {
		line := bufio.scanner_text(&scanner)
		log.warn(line) // or log.warn(line) if you prefer
	}

	// Check if we stopped due to an error
	if err := bufio.scanner_error(&scanner); err != nil {
		log.error("Scanner error:", err)
		return
	}
}
