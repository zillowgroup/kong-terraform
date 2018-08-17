data "aws_acm_certificate" "external-cert" {
  domain = "${var.ssl_cert_external}"
}

data "aws_acm_certificate" "internal-cert" {
  domain = "${var.ssl_cert_internal}"
}

data "aws_acm_certificate" "gui-cert" {
  domain = "${var.ssl_cert_internal_gui}"
}

# External - HTTPS only
resource "aws_alb_target_group" "external" {
  count = "${var.enable_external_lb}"

  name     = "${var.service}-${var.environment}-external"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc.id}"

  health_check {
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    interval            = "${var.health_check_interval}"
    path                = "/status"
    port                = 8000
    timeout             = "${var.health_check_timeout}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
  }

  tags = "${merge(
    map("Name", format("%s-%s-external", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb" "external" {
  count = "${var.enable_external_lb}"

  name     = "${var.service}-${var.environment}-external"
  internal = false
  subnets  = ["${data.aws_subnet_ids.public.ids}"]

  security_groups = [
    "${aws_security_group.external-lb.id}",
  ]

  enable_deletion_protection = "${var.enable_deletion_protection}"
  idle_timeout               = "${var.idle_timeout}"

  tags = "${merge(
    map("Name", format("%s-%s-external", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb_listener" "external-https" {
  count = "${var.enable_external_lb}"

  load_balancer_arn = "${aws_alb.external.arn}"
  port              = "443"
  protocol          = "HTTPS"

  ssl_policy      = "${var.ssl_policy}"
  certificate_arn = "${data.aws_acm_certificate.external-cert.arn}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.external.*.arn, 0)}"
    type             = "forward"
  }
}

# Internal
resource "aws_alb_target_group" "internal" {
  count = "${var.enable_internal_lb}"

  name     = "${var.service}-${var.environment}-internal"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc.id}"

  health_check {
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    interval            = "${var.health_check_interval}"
    path                = "/status"
    port                = 8000
    timeout             = "${var.health_check_timeout}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
  }

  tags = "${merge(
    map("Name", format("%s-%s-internal", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb_target_group" "internal-admin" {
  count = "${var.enable_ee}"

  name     = "${var.service}-${var.environment}-internal-admin"
  port     = 8001
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc.id}"

  health_check {
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    interval            = "${var.health_check_interval}"
    path                = "/status"
    port                = 8000
    timeout             = "${var.health_check_timeout}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
  }

  tags = "${merge(
    map("Name", format("%s-%s-internal-admin", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb_target_group" "internal-gui" {
  count = "${var.enable_ee}"

  name     = "${var.service}-${var.environment}-internal-gui"
  port     = 8002
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.vpc.id}"

  health_check {
    healthy_threshold   = "${var.health_check_healthy_threshold}"
    interval            = "${var.health_check_interval}"
    path                = "/status"
    port                = 8000
    timeout             = "${var.health_check_timeout}"
    unhealthy_threshold = "${var.health_check_unhealthy_threshold}"
  }

  tags = "${merge(
    map("Name", format("%s-%s-internal-gui", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb" "internal" {
  count = "${var.enable_internal_lb}"

  name     = "${var.service}-${var.environment}-internal"
  internal = true
  subnets  = ["${data.aws_subnet_ids.private.ids}"]

  security_groups = [
    "${aws_security_group.internal-lb.id}",
  ]

  enable_deletion_protection = "${var.enable_deletion_protection}"
  idle_timeout               = "${var.idle_timeout}"

  tags = "${merge(
    map("Name", format("%s-%s-internal", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_alb_listener" "internal-http" {
  count = "${var.enable_internal_lb}"

  load_balancer_arn = "${aws_alb.internal.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.internal.*.arn, 0)}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "internal-https" {
  count = "${var.enable_internal_lb}"

  load_balancer_arn = "${aws_alb.internal.arn}"
  port              = "443"
  protocol          = "HTTPS"

  ssl_policy      = "${var.ssl_policy}"
  certificate_arn = "${data.aws_acm_certificate.internal-cert.arn}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.internal.*.arn, 0)}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "internal-admin" {
  count = "${var.enable_ee}"

  load_balancer_arn = "${aws_alb.internal.arn}"
  port              = "8444"
  protocol          = "HTTPS"

  ssl_policy      = "${var.ssl_policy}"
  certificate_arn = "${data.aws_acm_certificate.gui-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.internal-admin.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "internal-gui" {
  count = "${var.enable_ee}"

  load_balancer_arn = "${aws_alb.internal.arn}"
  port              = "8445"
  protocol          = "HTTPS"

  ssl_policy      = "${var.ssl_policy}"
  certificate_arn = "${data.aws_acm_certificate.gui-cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.internal-gui.arn}"
    type             = "forward"
  }
}
