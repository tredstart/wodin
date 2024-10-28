package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
)

func main() {
	client := &http.Client{}
	http.HandleFunc("/v2/pipeline", func(w http.ResponseWriter, r *http.Request) {
		req, err := http.NewRequest(r.Method, "https://"+r.Host+r.URL.Path, r.Body)
		if err != nil {
			fmt.Println("error while creating new request, ", err)
		}
		req.Header = r.Header
		resp, err := client.Do(req)
		if err != nil {
			fmt.Println("err: ", err)
		}
		body, err := io.ReadAll(resp.Body)
		if err != nil {
			fmt.Println("Error reading response body:", err)
			return
		}
        log.Println(string(body))
		fmt.Fprintf(w, "status: %d\r\n%s\r\nEND\r\n", resp.StatusCode, string(body))
	})

	log.Fatal(http.ListenAndServe(":4200", nil))
}
