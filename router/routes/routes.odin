package routes

import "../../client"
import "../../env"
import "../../router"
import "core:fmt"
import "core:os"

home_list :: proc(req: router.Request) -> router.Response {
	rows := client.Rows{}
	defer delete(rows)
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
	for row in rows {
		item := fmt.tprintf(resp_body_item, row.x, row.z, row.y)
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
