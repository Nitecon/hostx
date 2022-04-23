HostX
=====

## Why does this exist?
In majority of all the highly available setups as well as hyper scaling I've always started with
block storage and heavy caching to keep servers up.  Having cloud storage as the backend makes
things way better than dealing with a filesystem.  With built-in caching for HostX most renders
will not even incur the transmit time from s3.  HostX is also multi threaded and compiled with
potential response times of 1ms - 10ms cached and average of 50ms read from S3.  Which is faster 
than most humans will notice anyway.

The secondary and most important item is cost.  Not just infrastructure cost but also human
operational cost...  Not having to maintain servers or deal with vulnerabilities from packages
on operating systems is a massive boost in efficiency.  Since containers are built `FROM scratch`
we only have to worry about golang language specific vulnerabilities which is true for both the lambda
and the container side of the world.

The final benefit is that you can run this locally on your desktop and point it to MinIO if you
desire without the need of using S3 at all.  And finally having to build Auth-N/Auth-Z for frontend
applications requires a huge effort... But ALB can do this, how about having envar to specify your
RBAC controls for your application in a very easy way?  See more about that later!

## What it is
HostX is a serverless and container based webserver which intends to solve the majority of frontend
portal and static wetbsite issues.  It's designed to minimize the amount of time spent getting a new
site up and running, but also minimizes the amount of human operational cost to support the application
especially when tied to AWS Lambda.  HostX's filesystem is based on cloud storage providers.  The primary
is using S3 compatible storage, you could spin up minio under a kubernetes cluster with access to minio
and your entire CI/CD for the appliction becomes building and pushing to S3.  The intent is to have
additional storage engines at some point in the future also but S3 is the primary focus currently.

Additional security based tasks that HostX will solve include OAuth based workflows and proper 3 legged
authentication.  This will remove a very large amount of effort from every day work as you no longer have
to build those parts, the initial integration will focus on google but a flexible integration will
also be added to include other providers like Ping Federate etc.

The final and most asked for capability comes within the proxy pass capabilities to be developed.
Just like standard ALB / httpd / nginx function which proxy to an API endpoint it will support the
same with the ability to in the future do backend only token transmission and authorization with API 
servers which allow a more streamlined implementation means to developers.  However this functionality
is likely to be limited to subscriptions due to the complexity with custom Auth-N & Auth-Z that is
integrated in API Gateways & Services.

## How HostX works?
### For production the recommended way is via AWS Lambda
> **_NOTE:_**  AWS Limits the invocation payload size of a lambda which means you cannot host
> assets larger than 1mb (gzipped) at any given time.  (Please help with the PFR for this!)  If
> you have assets larger than this please use the container mode.  Functionality & capabilities
> remain the same...


HostX can be deployed in 2 different configurations.  A more secured environment which enables
the use of fully private paths and hosting of the lambda within VPC bounds to further increase
security posture.  Why is this important?  You may want to ensure your SSO 3rd leg remains routable
only via a private network.  Additional proxy capabilities can also be limited only to internal 
network access.

![Fig1: Private VPC Mode](https://github.com/Nitecon/hostx/blob/main/docs/HostXLambdaPrivateVPCMode.png?raw=true)

For less restrictive environments where the intent is to host public applications without the need
to restrict traffic and the routing there of a secondary means can be used which only requires an 
ALB that is defined either on a public vpc or existing private location which adds an additional 
target group to invoke the lambda under a host name as example.  For public mode see below.

![Fig2: Public VPC Mode](https://github.com/Nitecon/hostx/blob/main/docs/HostXLambdaPublicMode.png?raw=true)

#### Note:
While the above shows example use cases they can be more extensive including WAFs and other filtering
technology prior to the application also.

### In container mode (EKS example)
> **_NOTE:_** WIP Container should be up shortly

HostX is capable of running in a container and as part of the build process produces the standard 
docker container which is available at: [HostX Docker](https://hub.docker.com/r/nitecon/hostx)

Example configuration for running HostX under kubernetes will be available under `examples` folder,
shortly.  Which can be fronted by Service of type LoadBalancer or NginX Ingress etc.
 
## How to Get Started!
Within the terraform directory there is a simple example currently which illustrates the creation
of a basic AWS public VPC, the creation of a lambda function & ALB with appropriate creation of
roles policies and attachment of them.  This is to bootstrap an installation using lambda.

If you prefer to work and test locally you can use the docker approach to start a container and just
point it directly to your minio / s3 endpoint from which it will serve your content directly.

## Enhanced capabilities
> **_NOTE:_** Many of the capabilities are a WIP but should be available shortly

* Rewrite Mode
  * Enables the ability to rewrite files that are not found back to the index
  * This enables the use of custom routers within frameworks like angular etc
  * Allows you to build custom error handling capabilities and simplifies single page apps
* Lockdown mode
  * Enables the ability to quickly make the application fully secured by the backend process.
  * Enables RBAC Path based approach to authentication based on roles from OAuth
  * Cookies to support Auth-N/Auth-Z is backend only cookies to enable best practices
  * Frontend application user information retrieved via `/_oauth/user-info` as non-conflicting path
* Secured Session Management
  * Makes use of customer provided AES hash / key to secure the application
* HashCorp Vault & Secrets Management
  * For securing environment variables the use of Vault & KMS will be usable in the future
  * Use of Vault in Containers as a native approach will be available.
  * Intention is to follow proper convention to unset envars once consumed and stored encrypted in memory
* GZip inline compression of assets
* Custom error pages
  * Similar to other web servers it allows the use of custom 404 / 500 error pages via a central prefix
* Multi site via a single S3 bucket
  * Reduce the amount of buckets used for your fleet of websites
  * Share error pages across multiple sites or keep them unique as needed
  * Restrict lambda execution access to S3 by prefix and limit to read only capability
* Caching
  * HostX has a built-in in memory caching solution to greatly improve the speed of your site
  * While the sub 50ms render times are already faster than solutions like Node.js this can reduce it even more
  * Additional cache adapters will be added in the future to make use of centralized caching like redis/memcache
  