package main

import (
    "fmt"
    "log"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hello from the Go backend!")
}

func main() {
    http.HandleFunc("/", handler)
    log.Println("Backend server starting on port 8080...")
    log.Fatal(http.ListenAndServe(":8080", nil))
}