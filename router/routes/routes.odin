package routes

import "../../client"
import "../../env"
import "../../router"
import "core:crypto/hash"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

home_list :: proc(req: router.Request) -> router.Response {
	rows := client.Rows {
		size = 3,
	}
	defer client.delete_rows(&rows)
	e, ok := env.parse_env(".env").?
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	content := "{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"SELECT id, created, title FROM articles\"}},{\"type\":\"close\"}]}"
	client.client_request(&rows, e, content)
	resp_body_item := `
    <div class="" hx-push-url="true" hx-get="/blog/%s" hx-trigger="click" hx-target="#content">
        <h3>%s</h3>
        <h4>%s</h4>
    </div>
    `
	resp_body: string
	for row in rows.rows {
		item := fmt.tprintf(resp_body_item, row[0], row[2], row[1])
		resp_body = fmt.tprintf("%s\n%s", item, resp_body)
	}
	return {200, "OK", "wodin", "text/html", resp_body, {}}
}

home :: proc(req: router.Request) -> router.Response {
	resp_body, ok := os.read_entire_file_from_filename("frontend/index.html")
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {200, "OK", "wodin", "text/html", string(resp_body), {}}
}

login :: proc(req: router.Request) -> router.Response {
	resp_body, ok := os.read_entire_file_from_filename("frontend/login.html")
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {200, "OK", "wodin", "text/html", string(resp_body), {}}
}

article :: proc(req: router.Request) -> router.Response {
	rows := client.Rows {
		size = 4,
	}
	defer client.delete_rows(&rows)
	e, ok := env.parse_env(".env").?
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	article_id, exists := req.path_params["article"]
	if !exists {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	query := fmt.tprintf("SELECT * FROM articles WHERE id='%s'", article_id)
	content := fmt.tprint(
		"{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"",
		query,
		"\"}},{\"type\":\"close\"}]}",
	)
	client.client_request(&rows, e, content)
	if len(rows.rows) < 1 {
		return {
			status_code = 404,
			status = "Internal server error",
			body = "Article does not exits. I'm sorry.",
		}
	}
	art := rows.rows[0]

	resp_body_item := `
    <div class="">
        <div class="">
            <h1>%s</h1>
            <h3>%s</h3>
        </div>
        <div class="">
        %s
        </div>
    </div>
    `
	resp_body := fmt.tprintf(resp_body_item, art[3], art[2], art[1])
	return {200, "OK", "wodin", "text/html", resp_body, {}}
}

verify_login :: proc(req: router.Request) -> bool {
	cookie, cook_ok := req.headers["Cookie"]
	if !cook_ok {
		return false
	}
	split := strings.split(cookie, "=")
	current_hash, hash_ok := os.read_entire_file_from_filename("current_hash")
	if !hash_ok {
		return false
	}
	if len(split) < 2 || string(current_hash) != split[1] {
		return false
	}
	return true
}

login_post :: proc(req: router.Request) -> router.Response {
	e, ok := env.parse_env(".env").?
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	pass := e.pass
	pp, form_ok := req.form_data["password"]
	if !form_ok {
		return {400, "Bad Request", "wodin", "text/html", "Request without password", {}}
	}

	s := hash_it(pp)
	if pass != s {
		return {401, "Unauthorized", "wodin", "text/html", "Wrong password", {}}
	}
	key := hash_it(fmt.tprintf("%s%v", pass, time.now()))
	ok = os.write_entire_file("current_hash", transmute([]byte)key)
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {
		303,
		"See Other",
		"wodin",
		"text/html",
		"<html>What</html>",
		{
			"Location" = "/create-article",
			"Connection" = "close",
			"Set-Cookie" = fmt.tprintf("key=%s; Max-Age=%d; SameSite=Strict", key, 24 * 60 * 60),
		},
	}
}

create_article :: proc(req: router.Request) -> router.Response {
	if !verify_login(req) {
		return {
			303,
			"See Other",
			"wodin",
			"text/html",
			"<html>What</html>",
			{"Location" = "/login", "Connection" = "close"},
		}
	}
	resp_body, ok := os.read_entire_file_from_filename("frontend/form.html")
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {200, "OK", "wodin", "text/html", string(resp_body), {}}
}

post_article :: proc(req: router.Request) -> router.Response {
	if !verify_login(req) {
		return {
			303,
			"See Other",
			"wodin",
			"text/html",
			"<html>What</html>",
			{"Location" = "/login", "Connection" = "close"},
		}
	}


	pp, title_ok := req.form_data["title"]
	if !title_ok {
		return {400, "Bad Request", "wodin", "text/html", "Request without title", {}}
	}
	content, content_ok := req.form_data["content"]
	if !title_ok {
		return {400, "Bad Request", "wodin", "text/html", "Request without content", {}}
	}

	t := fmt.tprintf("%v", time.now())
	uuid := hash_it(t)


	rows := client.Rows {
		size = 3,
	}
	defer client.delete_rows(&rows)
	e, ok := env.parse_env(".env").?
	if !ok {
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}

	query := fmt.tprintf(
		"INSERT INTO articles VALUES ('%s', '%s', '%s', '%s')",
		uuid,
		content,
		t,
		pp,
	)
	c := fmt.tprint(
		"{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"",
		query,
		"\"}},{\"type\":\"close\"}]}",
	)
	client.client_request(&rows, e, c)
	return {
		303,
		"See Other",
		"wodin",
		"text/html",
		"<html>What</html>",
		{"Location" = "/", "Connection" = "close"},
	}
}

@(private)
hash_it :: proc(pp: string) -> string {
	rd := hash.hash(hash.Algorithm.SHA512_256, pp)
	defer delete(rd)
	s: string
	for h in rd {
		s = fmt.tprintf("%s%x", s, h)
	}
	return s
}
