package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"sort"
	"strconv"
)

type fileEntry struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

func main() {
	port := 3000
	if rawPort := os.Getenv("PORT"); rawPort != "" {
		parsedPort, err := strconv.Atoi(rawPort)
		if err != nil {
			log.Fatalf("invalid PORT %q: %v", rawPort, err)
		}
		port = parsedPort
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", rootHandler)
	mux.HandleFunc("/hello", helloHandler)
	mux.HandleFunc("/files", filesHandler)

	addr := "127.0.0.1:" + strconv.Itoa(port)
	log.Printf("Local Go API listening on http://%s", addr)
	if err := http.ListenAndServe(addr, withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "*")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"message": "Local Bridge API is running",
		"hello":   "/hello",
		"files":   "/files",
	})
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/hello" {
		http.NotFound(w, r)
		return
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte("world"))
}

func filesHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/files" {
		http.NotFound(w, r)
		return
	}

	desktopPath, err := currentDesktopPath()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{
			"error":   "Failed to read desktop files",
			"message": err.Error(),
			"path":    "",
		})
		return
	}

	entries, err := os.ReadDir(desktopPath)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{
			"error":   "Failed to read desktop files",
			"message": err.Error(),
			"path":    desktopPath,
		})
		return
	}

	files := make([]fileEntry, 0, len(entries))
	for _, entry := range entries {
		fileType := "other"
		if entry.IsDir() {
			fileType = "directory"
		} else if entry.Type().IsRegular() {
			fileType = "file"
		}

		files = append(files, fileEntry{
			Name: entry.Name(),
			Type: fileType,
		})
	}

	sort.Slice(files, func(i, j int) bool {
		return files[i].Name < files[j].Name
	})

	writeJSON(w, http.StatusOK, map[string]any{
		"path":  desktopPath,
		"count": len(files),
		"files": files,
	})
}

func currentDesktopPath() (string, error) {
	currentUser, err := user.Current()
	if err != nil {
		return "", err
	}

	return filepath.Join(currentUser.HomeDir, "Desktop"), nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)

	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(payload); err != nil {
		log.Printf("failed to encode JSON response: %v", err)
	}
}
