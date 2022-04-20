package cache

import (
	"bytes"
	"compress/gzip"
	"github.com/patrickmn/go-cache"
	"github.com/rs/zerolog/log"
	"io/ioutil"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

var (
	svc     *cache.Cache
	svcLock = new(sync.RWMutex)
)

type ContentItem struct {
	Headers map[string]string
	Status  int
	Body    []byte
}

func InitCache() {
	cTTL, err := strconv.Atoi(os.Getenv("CACHE_EXPIRE_TTL"))
	if err != nil {
		cTTL = 5 * 60 // 5 minute expire by default
	}
	cPurge, err := strconv.Atoi(os.Getenv("CACHE_PURGE_TTL"))
	if err != nil {
		cPurge = 10 * 60 // 10 minute purge timer
	}
	//svcLock.Lock()
	//defer svcLock.Unlock()
	svc = cache.New(time.Duration(cTTL)*time.Second, time.Duration(cPurge)*time.Second)
}

func GetContent(key, acceptEncoding string) (*ContentItem, bool) {
	if x, exp, found := svc.GetWithExpiration(key); found {
		content := x.(*ContentItem)
		content.Headers["HostX-Cache-Expire"] = exp.String()
		if strings.Contains(acceptEncoding, "gzip") {
			log.Debug().Msg("providing gzip body and appropriate headers data.")
			content.Headers["Vary"] = "Accept-Encoding"
			content.Headers["Content-Encoding"] = "gzip"
		} else {
			buf := bytes.NewReader(content.Body)
			gzReader, err := gzip.NewReader(buf)
			if err != nil {
				log.Err(err).Msg("unable to create a gzip reader")
				return content, true
			}
			fd, err := ioutil.ReadAll(gzReader)
			if err != nil {
				log.Err(err).Msg("could not decompress body will return as is...")
				return content, true
			}
			content.Body = fd
		}
		return content, true
	}
	return nil, false
}

// Caches body content and returns gzipped body as result.
func SaveContent(key string, headers map[string]string, status int, body []byte) []byte {
	cItem := &ContentItem{Headers: headers, Status: status}
	buf := &bytes.Buffer{}
	gzWriter := gzip.NewWriter(buf)
	gzWriter.Write([]byte(body))
	gzWriter.Close()
	cItem.Body = buf.Bytes()
	svc.Set(key, cItem, cache.DefaultExpiration)
	return cItem.Body
}
