package s3

import (
	"context"
	"hostx/cache"
	"io/ioutil"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/rs/zerolog/log"
)

var (
	Svc *S3Service
)

// getStorageKey returns the proper storage key in s3 and boolean true if it's the root index
func getStorageKey(reqKey string) string {
	if reqKey[len(reqKey)-1:] == "/" {
		reqKey = reqKey + os.Getenv("INDEX_FILE")
	}
	fullKey := Svc.Prefix + reqKey
	log.Debug().Msgf("Storage Key: %s", fullKey)
	return fullKey
}

func setHeaders(w http.ResponseWriter, headers map[string]string) {
	for k, v := range headers {
		w.Header().Set(k, v)
	}
}

func StaticHandler(w http.ResponseWriter, r *http.Request) {
	storageKey := getStorageKey(r.URL.Path)
	if os.Getenv("USE_CACHE") != "false" {
		if cData, found := cache.GetContent(storageKey, r.Header.Get("Accept-Encoding")); found {
			w.WriteHeader(cData.Status)
			for k, v := range cData.Headers {
				w.Header().Set(k, v)
			}
			w.Write(cData.Body)
			return
		}
	}

	ctx := context.Background()
	ctx, cancelFn := context.WithTimeout(ctx, Svc.Timeout)
	// Ensure the context is canceled to prevent leaking.
	// See context package for more information, https://golang.org/pkg/context/
	defer cancelFn()
	fd, err := Svc.Service.GetObjectWithContext(ctx, &s3.GetObjectInput{
		Bucket: aws.String(Svc.Bucket),
		Key:    aws.String(storageKey),
	})
	if err != nil {
		log.Debug().Err(err).Msg("Fetching object from S3 failed. Returning 404.")
		w.WriteHeader(http.StatusNotFound) // StatusNotFound = 404
		w.Write([]byte(" The page you requested could not be found."))
		return
	}
	d, err := ioutil.ReadAll(fd.Body)
	if err != nil {
		log.Error().Err(err).Msg("unable to read body data from s3 file")
		w.WriteHeader(http.StatusNotFound) // StatusNotFound = 404
		w.Write([]byte("the page you requested could not be found."))
		return
	}
	headers := make(map[string]string)
	if *fd.ContentType == "" {
		headers["Content-Type"] = http.DetectContentType(d)
	} else {
		headers["Content-Type"] = *fd.ContentType
	}
	gzData := cache.SaveContent(storageKey, headers, http.StatusFound, d)
	setHeaders(w, headers)
	if strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
		log.Debug().Msg("providing gzip body and appropriate headers data.")
		w.Header().Set("Vary", "Accept-Encoding")
		w.Header().Set("Content-Encoding", "gzip")
		w.WriteHeader(http.StatusFound)
		w.Write(gzData)
		return
	}
	w.WriteHeader(http.StatusFound)
	w.Write(d)
}

func CheckExists(key string) bool {
	ctx := context.Background()
	ctx, cancelFn := context.WithTimeout(ctx, Svc.Timeout)
	// Ensure the context is canceled to prevent leaking.
	// See context package for more information, https://golang.org/pkg/context/
	defer cancelFn()
	_, err := Svc.Service.HeadObjectWithContext(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(Svc.Bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return false
	}
	return true
}

func ShouldCache(loc string) bool {
	noCachePaths := strings.Split(os.Getenv("REQUEST_NO_CACHE"), ",")
	for _, v := range noCachePaths {
		if v == loc {
			return false
		}
	}
	return true
}

func RewriteHandler(w http.ResponseWriter, r *http.Request) {
	storageKey := getStorageKey(r.URL.Path)
	if !CheckExists(storageKey) {
		log.Debug().Msgf("%s does not exist, rewriting to index", storageKey)
		storageKey = getStorageKey("/")
	}

	if os.Getenv("USE_CACHE") == "true" && ShouldCache(storageKey) {
		if cData, found := cache.GetContent(storageKey, r.Header.Get("Accept-Encoding")); found {
			w.WriteHeader(cData.Status)
			for k, v := range cData.Headers {
				w.Header().Set(k, v)
			}
			w.Write(cData.Body)
			return
		}
	}

	ctx := context.Background()
	ctx, cancelFn := context.WithTimeout(ctx, Svc.Timeout)
	// Ensure the context is canceled to prevent leaking.
	// See context package for more information, https://golang.org/pkg/context/
	defer cancelFn()
	fd, err := Svc.Service.GetObjectWithContext(ctx, &s3.GetObjectInput{
		Bucket: aws.String(Svc.Bucket),
		Key:    aws.String(storageKey),
	})
	if err != nil {
		log.Debug().Err(err).Msg("in rewrite mode we shouldn't get 404")
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte("error retrieving page"))
		return
	}
	d, err := ioutil.ReadAll(fd.Body)
	if err != nil {
		log.Error().Err(err).Msg("unable to read body data from s3 file")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("cannot read body content"))
		return
	}
	headers := make(map[string]string)
	if *fd.ContentType == "" {
		headers["Content-Type"] = http.DetectContentType(d)
	} else {
		headers["Content-Type"] = *fd.ContentType
	}
	gzData := cache.SaveContent(storageKey, headers, http.StatusFound, d)
	setHeaders(w, headers)
	if strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
		log.Debug().Msg("providing gzip body and appropriate headers data.")
		w.Header().Set("Vary", "Accept-Encoding")
		w.Header().Set("Content-Encoding", "gzip")
		w.WriteHeader(http.StatusFound)
		w.Write(gzData)
		return
	}
	w.WriteHeader(http.StatusFound)
	w.Write(d)
}
