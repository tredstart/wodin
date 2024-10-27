package client_test

import "../../client"
import "../../env"
import "core:testing"

@(test)
test_database_request :: proc(t: ^testing.T) {
	e, ok := env.parse_env("test.env").?
	assert(ok)
	assert(e.db_key != "" && e.db_addr != "")
	content := "{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"SELECT * FROM articles\"}},{\"type\":\"close\"}]}"
	r := client.Rows{}
	defer delete(r)
	client.client_request(&r, e, content)
	assert(len(r) != 0)
}
