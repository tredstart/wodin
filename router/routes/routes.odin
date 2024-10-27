package routes

import "../../client"
import "../../env"
import "../../router"
import "core:fmt"
import "core:log"
import "core:os"

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
    <div class="" hx-get="/blog/%s" hx-trigger="click" hx-target="#content">
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
