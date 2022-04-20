package main

import (
	"context"
	"hostx/alb"
	"hostx/cache"
	"hostx/storage/s3"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/julienschmidt/httprouter"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

var (
	version = "source"
	router  *httprouter.Router
)

func setLogger() {
	h, err := os.Hostname()
	if err != nil {
		h = "unknown.hostname"
	}
	zerolog.New(os.Stdout).With().
		Timestamp().
		Str("role", "my-service").
		Str("host", h).
		Logger()
	zerolog.TimeFieldFormat = time.RFC3339Nano
	if os.Getenv("DEBUG") != "" {
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
	} else {
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
	}
}

func LambdaInit(ctx context.Context, request events.ALBTargetGroupRequest) (events.ALBTargetGroupResponse, error) {
	return *alb.LambdaResponse(request), nil
}

func main() {
	setLogger()
	// This cache is also useful for lambda's so it's global not just for containers
	// due to the way that lambda's can be invoked with shared memory
	cache.InitCache()
	log.Info().Msgf("Starting HostX (Version: %s)", version)
	if os.Getenv("STORAGE_TYPE") == "s3" {
		log.Debug().Msg("Initializing S3 Storage")
		s3.Svc = &s3.S3Service{Bucket: os.Getenv("BUCKET"), Prefix: os.Getenv("PREFIX")}
		s3.Svc.Initialize()

	}
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") != "" {
		log.Info().Msgf("Operating Mode: %s", "lambda")
		lambda.Start(LambdaInit)
		return
	}
	log.Info().Msgf("Operating Mode: %s", "webserver")
	if os.Getenv("USE_REWRITE") != "" && strings.ToLower(os.Getenv("USE_REWRITE")) != "false" {
		http.HandleFunc("/", s3.RewriteHandler)
	} else {
		http.HandleFunc("/", s3.StaticHandler)
	}
	listenPort := os.Getenv("HTTP_PORT")
	if listenPort == "" {
		listenPort = ":8080"
	}

	log.Fatal().Err(http.ListenAndServe(listenPort, nil))

}
