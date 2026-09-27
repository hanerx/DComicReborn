package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"dcomic-sync-server/internal/httpserver"
	"dcomic-sync-server/internal/store"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) == 0 {
		return usageError()
	}
	switch args[0] {
	case "serve":
		return serve(args[1:])
	case "help", "-h", "--help":
		printUsage()
		return nil
	default:
		return fmt.Errorf("unknown command %q\n\n%s", args[0], usageText)
	}
}

const usageText = `Usage:
  dcomic-server serve [options]

Run "dcomic-server serve -h" for command options.`

func printUsage()       { fmt.Fprintln(os.Stderr, usageText) }
func usageError() error { return errors.New(usageText) }

func envOr(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func prepareDatabase(path string) error {
	directory := filepath.Dir(path)
	if directory == "." {
		return nil
	}
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return fmt.Errorf("create database directory: %w", err)
	}
	return nil
}

func serve(args []string) error {
	flags := flag.NewFlagSet("serve", flag.ContinueOnError)
	listen := flags.String("listen", envOr("DCOMIC_LISTEN", "0.0.0.0:8080"), "listen address (env DCOMIC_LISTEN)")
	database := flags.String("db", envOr("DCOMIC_DB", "data/dcomic.db"), "SQLite database path (env DCOMIC_DB)")
	publicURL := flags.String("public-url", envOr("DCOMIC_PUBLIC_URL", ""), "optional exact public HTTP(S) origin (env DCOMIC_PUBLIC_URL)")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return fmt.Errorf("serve takes no positional arguments")
	}
	if err := prepareDatabase(*database); err != nil {
		return err
	}
	data, err := store.Open(*database)
	if err != nil {
		return err
	}
	defer data.Close()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	handler, err := httpserver.New(data, httpserver.Config{PublicURL: *publicURL, Logger: logger})
	if err != nil {
		return err
	}
	server := &http.Server{
		Addr: *listen, Handler: handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		IdleTimeout:       75 * time.Second,
		MaxHeaderBytes:    32 << 10,
	}
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stop
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := server.Shutdown(ctx); err != nil {
			logger.Error("graceful shutdown", "error", err)
		}
	}()
	logger.Info("server listening", "address", *listen, "public_url", *publicURL, "database", *database)
	err = server.ListenAndServe()
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}
