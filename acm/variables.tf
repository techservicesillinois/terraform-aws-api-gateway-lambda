variable "aliases" {
  type    = list(string)
  default = []
}

variable "create_acm_cert" {
  default = true
}

variable "create_route53_record" {
  default = true
}

variable "domain" {
}

variable "hostname" {
}

variable "target_domain" {
}

variable "zone_id" {
}
