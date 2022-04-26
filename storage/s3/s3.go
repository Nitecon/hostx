package s3

import (
	"fmt"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3iface"
	"github.com/rs/zerolog/log"
	"os"
	"time"
)

type S3Service struct {
	Session  *session.Session
	Bucket   string
	Prefix   string
	Endpoint string
	Timeout  time.Duration
	Service  s3iface.S3API
}

func (s *S3Service) Initialize() error {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		if os.Getenv("AWS_DEFAULT_REGION") == "" {
			region = "us-east-1"
		} else {
			region = os.Getenv("AWS_DEFAULT_REGION")
		}
	}

	if s.Endpoint == "" {
		s.Endpoint = fmt.Sprintf("s3.%s.amazonaws.com", region)
	}
	if s.Prefix[len(s.Prefix)-1:] == "/" {
		s.Prefix = s.Prefix[:len(s.Prefix)-1]
	}

	s.Timeout = time.Duration(10 * time.Second)
	creds := credentials.NewEnvCredentials()
	log.Debug().Msgf("Using Bucket [%s] With Prefix [%s] on [%s]", s.Bucket, s.Prefix, s.Endpoint)
	sess, err := session.NewSessionWithOptions(session.Options{Config: aws.Config{Region: aws.String(region), Endpoint: aws.String(s.Endpoint), Credentials: creds}})
	if err != nil {
		log.Debug().Msg("Could not initialize AWS session")
		return err
	}
	//log.Debug().Interface("ProxyClient", httpClient)
	s.Service = s3.New(sess)
	return nil
}
