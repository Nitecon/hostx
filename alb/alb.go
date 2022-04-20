package alb

import (
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/rs/zerolog/log"
	"hostx/storage/s3"
	"net/http"
	"os"
	"strings"
)

type AlbResponseWriter struct {
	body       []byte
	statusCode int
	header     http.Header
}

func NewAlbResponseWriter() *AlbResponseWriter {
	hdr := http.Header{}
	hdr.Set("X-Server", "HostX")
	hdr.Set("Access-Control-Allow-Origin", os.Getenv("CORS"))
	return &AlbResponseWriter{
		header: hdr,
	}
}

func (w *AlbResponseWriter) Header() http.Header {
	return w.header
}

func (w *AlbResponseWriter) Write(b []byte) (int, error) {
	w.body = b
	// implement it as per your requirement
	return 0, nil
}

func (w *AlbResponseWriter) WriteHeader(statusCode int) {
	w.statusCode = statusCode
}

var okFn = func(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func generateRequest(r events.ALBTargetGroupRequest) *http.Request {
	req, err := http.NewRequest(r.HTTPMethod, r.Path, strings.NewReader(r.Body))
	if err != nil {
		log.Fatal().Err(err).Msg("could not instantiate request")
	}
	q := req.URL.Query()
	for k, v := range r.QueryStringParameters {
		q.Add(k, v)
	}
	req.URL.RawQuery = q.Encode()
	return req
}

func LambdaResponse(ar events.ALBTargetGroupRequest) *events.ALBTargetGroupResponse {
	aw := NewAlbResponseWriter()
	req := generateRequest(ar)
	if os.Getenv("USE_REWRITE") != "" && strings.ToLower(os.Getenv("USE_REWRITE")) != "false" {
		s3.RewriteHandler(aw, req)
	} else {
		s3.StaticHandler(aw, req)
	}

	a := &events.ALBTargetGroupResponse{}
	a.Headers = make(map[string]string)
	a.MultiValueHeaders = make(map[string][]string)
	for k, v := range aw.Header() {
		a.Headers[k] = strings.Join(v, ",")
		a.MultiValueHeaders[k] = v
	}
	log.Debug().Msgf("Body size: %s", fmt.Sprintf("%.2f KB", float64(len(aw.body))/1024.0))
	a.Body = string(aw.body)
	a.StatusCode = aw.statusCode
	a.StatusDescription = http.StatusText(aw.statusCode)
	a.IsBase64Encoded = false
	return a
}
