# Manage Route 53 alias record for public zone.

data "aws_route53_zone" "selected" {
  count = var.create_route53_record ? 1 : 0

  name = var.domain
}

resource "aws_route53_record" "default" {
  count = var.create_route53_record ? 1 : 0

  # Zone and name of Route53 record being managed.
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.hostname
  type    = "A"

  alias {
    # Target of Route53 alias.
    name                   = var.target_domain
    evaluate_target_health = true
    zone_id                = var.zone_id
  }
}
