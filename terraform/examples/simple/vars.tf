variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "name" {
  type = string
}

variable "env" {
  type = string
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "availability_zones" {
  type = list(string)
}

variable "private_subnets_cidr" {
  type = list(string)
}

variable "app" {
  description = "Your application name lambda function will contain this"
  type        = string
}

variable "zipfile" {
  description = "Build system will create this and should be picked up by tf"
  type        = string
}

variable "UseCaching" {
  description = "Defines whether or not to use the built in caching system"
  type        = string
  default = "true"
}

variable "CacheExpire" {
  description = "Defines the time in seconds when cache will expire"
  type        = string
  default = "30"
}

variable "CachePurge" {
  description = "Defines time in seconds until cache is purged"
  type        = string
  default = "60"
}

variable "StorageType" {
  description = "Defines the standard storage type to be used by hostx"
  type        = string
  default = "s3"
}

variable "lambda_logs_expiration_days" {
  default = 1
}

variable "lb_access_logs_expiration_days" {
  default = "3"
}

variable "use_internal_lb" {
  description = "Whether to launch an internal or external ALB for the service."
  type = string
}

variable "fqdn" {
  description = "The FQDN where the site will be hosted"
  type = string
}

variable "r53domain" {
  description = "The zone to update where the new dns record must be created."
  type = string
}

variable "indexFile" {
  description = "update this if you're using different index files."
  type        = string
  default = "index.html"
}

variable "errorsRoot" {
  description = "The directory containing custom error messages if not set, hostx will render default errors templates"
  type        = string
}

variable "contentBucket" {
  description = "the bucket where all your content will be"
  type        = string
}

variable "siteRoot" {
  description = "the subdirectory where all the content lives, this is your site root"
  type        = string
}

variable "useRewriteMode" {
  description = "whether you want to use url rewriting back to the index file, use with js frameworks that have routers based on slugs"
  type        = string
}

variable "useDebugMode" {
  description = "whether you want to use debug logging"
  type        = string
}

variable "cors" {
  description = "This is the Access-Control-Allow-Origin header, and is discouraged to use * here, use your actual API server hostname here."
  type        = string
}

variable "noCachePaths" {
  description = "This is a comma separated lists of paths that when requested the response back to the browser will be to not cache the file."
  type        = string
}
