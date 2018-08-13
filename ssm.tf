resource "aws_kms_key" "kong" {
  description = "${var.service}/${var.environment}"

  tags = "${merge(
    map("Name", format("%s-%s", var.service, var.environment),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_kms_alias" "kong" {
  name          = "alias/${var.service}-${var.environment}"
  target_key_id = "${aws_kms_key.kong.key_id}"
}

resource "aws_ssm_parameter" "ee-bintray-auth" {
  name  = "/${var.service}/${var.environment}/ee/bintray-auth"
  type  = "String"
  value = "placeholder"

  overwrite = true
}

resource "aws_ssm_parameter" "ee-license" {
  name  = "/${var.service}/${var.environment}/ee/license"
  type  = "SecureString"
  value = "placeholder"

  key_id = "${aws_kms_alias.kong.target_key_arn}"

  lifecycle {
    ignore_changes = ["value"]
  }
}

resource "aws_ssm_parameter" "ee-admin-token" {
  name  = "/${var.service}/${var.environment}/ee/admin/token"
  type  = "SecureString"
  value = "zg-kong-2-1"

  key_id = "${aws_kms_alias.kong.target_key_arn}"

  lifecycle {
    ignore_changes = ["value"]
  }
}

resource "aws_ssm_parameter" "db-host" {
  name  = "/${var.service}/${var.environment}/db/host"
  type  = "String"
  value = "${coalesce(join("", aws_rds_cluster.kong.*.endpoint), var.db_host)}"
}

resource "aws_ssm_parameter" "db-name" {
  name  = "/${var.service}/${var.environment}/db/name"
  type  = "String"
  value = "${replace(format("%s_%s", var.service, var.environment), "-", "_")}"
}

resource "aws_ssm_parameter" "db-password" {
  name  = "/${var.service}/${var.environment}/db/password"
  type  = "SecureString"
  value = "placeholder"

  key_id = "${aws_kms_alias.kong.target_key_arn}"

  lifecycle {
    ignore_changes = ["value"]
  }

  overwrite = true
}

resource "aws_ssm_parameter" "db-master-password" {
  name  = "/${var.service}/${var.environment}/db/password/master"
  type  = "SecureString"
  value = "${var.db_password}"

  key_id = "${aws_kms_alias.kong.target_key_arn}"

  lifecycle {
    ignore_changes = ["value"]
  }

  overwrite = true
}
