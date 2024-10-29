package routes

import "../../client"
import "../../env"
import "../../router"
import "core:crypto/hash"
import "core:encoding/base64"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:time"

home_list :: proc(req: router.Request) -> router.Response {
	rows := client.Rows{}
	defer delete(rows)
	e, ok := env.parse_env(".env").?
	if !ok {
		log.warn("Cannot parse .env")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	content := "{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"SELECT id, created, title FROM articles\"}},{\"type\":\"close\"}]}"
	client.client_request(&rows, e, content)
	resp_body_item := `
    <div 
        class="hover:cursor-pointer border border-white w-full p-16 h-60 border-box" 
        hx-push-url="true" 
        hx-get="/blog/%s" 
        hx-trigger="click" hx-target="#content" hx-swap="outerHTML">
        <h3>%s</h3>
        <h4>%s</h4>
    </div>
    `
	resp_body: string
	for row in rows {
		item := fmt.tprintf(resp_body_item, row[0], row[2], row[1])
		resp_body = fmt.tprintf("%s\n%s", item, resp_body)
	}
	return {200, "OK", "wodin", "text/html", resp_body, {}}
}

home :: proc(req: router.Request) -> router.Response {
	resp_body, ok := os.read_entire_file_from_filename("frontend/index.html")
	if !ok {
		log.warn("Cannot read index.html")
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
		log.warn("Cannot read login.html")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {200, "OK", "wodin", "text/html", string(resp_body), {}}
}


about :: proc(req: router.Request) -> router.Response {
	resp_body, ok := os.read_entire_file_from_filename("frontend/about.html")
	if !ok {
		log.warn("Cannot read about.html")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	return {200, "OK", "wodin", "text/html", string(resp_body), {}}
}

article :: proc(req: router.Request) -> router.Response {
	rows := client.Rows{}
	defer delete(rows)
	e, ok := env.parse_env(".env").?
	if !ok {
		log.warn("Cannot parse .env (article)")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}
	article_id, exists := req.path_params["article"]
	if !exists {
		log.warn("No article in parameter")
		return {status_code = 404, status = "Not found", body = "Page does not exist"}
	}
	query := fmt.tprintf("SELECT content, created, title FROM articles WHERE id='%s'", article_id)
	c := fmt.tprint(
		"{\"requests\":[{\"type\":\"execute\",\"stmt\":{\"sql\":\"",
		query,
		"\"}},{\"type\":\"close\"}]}",
	)
	client.client_request(&rows, e, c)
	if len(rows) < 1 {
		return {
			status_code = 404,
			status = "Internal server error",
			body = "Article does not exits. I'm sorry.",
		}
	}
	article := rows[0]
	pp := article.z
	content := string(base64.decode(article.x))

	content, _ = strings.replace_all(content, "%0A", "\n")
	content, _ = strings.replace_all(content, "%3F", "?")
	content, _ = strings.replace_all(content, "%2C", ",")
	content, _ = strings.replace_all(content, "%26", "&")
	content, _ = strings.replace_all(content, "%23", "#")
	content, _ = strings.replace_all(content, "%3A", ":")
	content, _ = strings.replace_all(content, "%7B", "{")
	content, _ = strings.replace_all(content, "%7D", "}")
	content, _ = strings.replace_all(content, "%2B", "+")
	content, _ = strings.replace_all(content, "%25", "%")
	content, _ = strings.replace_all(content, "%5C", "\\")
	content, _ = strings.replace_all(content, "%5B", "[")
	content, _ = strings.replace_all(content, "%5D", "]")
	content, _ = strings.replace_all(content, "%24", "$")
	content, _ = strings.replace_all(content, "%40", "@")
	content, _ = strings.replace_all(content, "%E2%9E%9C", "-> ")
	content, _ = strings.replace_all(content, "%E2%9C%97", " $ ")

	div := `<div id="content" class="w-[65%] mt-20 box-border">`

	resp_body_item := fmt.tprintf(
		`<div class="p-4 box-border">
            <h1>%s</h1>
            <h3>%s</h3>
        </div>
        <div class="border-t border-b border-white border-solid p-4">
        %s
        </div>
    </div>
    `,
		pp,
		article.y,
		content,
	)
	resp_body := fmt.tprintf("%s%s", div, resp_body_item)
	hx_req, hx_ok := req.headers["HX-Request"]
	if !hx_ok {
		template, file_ok := os.read_entire_file_from_filename("frontend/article.html")
		if !file_ok {
			log.warn("Cannot read article")
			return {
				status_code = 500,
				status = "Internal server error",
				body = "Internal server error",
			}
		}
		rsp, _ := strings.replace(string(template), "%s", resp_body, 1)
		return {200, "OK", "wodin", "text/html", rsp, {}}
	}

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
		log.warn("Cannot read .env (post login)")
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
		log.warn("Cannot write to a file current hash")
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
		log.warn("Cannot read form.html")
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
		log.error("no title, ", req.form_data)
		return {400, "Bad Request", "wodin", "text/html", "Request without title", {}}
	}
	content, content_ok := req.form_data["content"]
	if !title_ok {
		log.error("no content, ", req.form_data)
		return {400, "Bad Request", "wodin", "text/html", "Request without content", {}}
	}

	t := fmt.tprintf("%v", time.now())
	uuid := hash_it(t)

	date := strings.split(t, " ")
	defer delete(date)


	rows := client.Rows{}
	defer delete(rows)
	e, ok := env.parse_env(".env").?
	if !ok {
        log.warn("Cannot read .env post article")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
		}
	}

	pp, _ = strings.replace_all(pp, "%20", " ")
	pp, _ = strings.replace_all(pp, "%3B", ";")

	content, _ = strings.replace_all(content, "%20", " ")
	content, _ = strings.replace_all(content, "%3B", ";")
	content, _ = strings.replace_all(content, "%3C", "<")
	content, _ = strings.replace_all(content, "%3D", "=")
	content, _ = strings.replace_all(content, "%22", "\"")
	content, _ = strings.replace_all(content, "%3E", ">")
	content, _ = strings.replace_all(content, "%2F", "/")

	b := base64.encode(transmute([]byte)content)

	query := fmt.tprintf(
		"INSERT INTO articles VALUES ('%s', '%s', '%s', '%s')",
		uuid,
		b,
		date[0],
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

styles :: proc(req: router.Request) -> router.Response {
	resp_body, ok := os.read_entire_file_from_filename("frontend/css/out.css")
	if !ok {
        log.warn("Cannot read css file")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
			server = "wodin",
		}
	}
	return {
		200,
		"OK",
		"wodin",
		"text/css",
		string(resp_body),
		{"X-Frame-Options" = "SAMEORIGIN", "X-XSS-Protection" = "1; mode=block"},
	}
}

images :: proc(req: router.Request) -> router.Response {
	filename, exists := req.path_params["name"]
	if !exists {
		log.warn("filename not provided")
		return {status_code = 404, status = "Not Found", body = "Not found", server = "wodin"}
	}
	log.warn(filename)
	resp_body, ok := os.read_entire_file_from_filename(fmt.tprintf("images/%s", filename))
	if !ok {
        log.warn("Cannot read image")
		return {
			status_code = 500,
			status = "Internal server error",
			body = "Internal server error",
			server = "wodin",
		}
	}
	return {
		200,
		"OK",
		"wodin",
		"image/*",
		string(resp_body),
		{"X-Frame-Options" = "SAMEORIGIN", "X-XSS-Protection" = "1; mode=block"},
	}
}
