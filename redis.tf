resource "aws_elasticache_replication_group" "kong" {
  count = "${var.enable_redis}"

  replication_group_id          = "${var.service}-${var.environment}"
  replication_group_description = "${var.description}"

  engine                = "redis"
  engine_version        = "4.0.10"
  node_type             = "${var.redis_instance_type}"
  number_cache_clusters = "${var.redis_instance_count}"
  parameter_group_name  = "${var.service}-${var.environment}"
  port                  = 6379

  subnet_group_name  = "${var.redis_subnets}"
  security_group_ids = ["${aws_security_group.redis.id}"]

  tags = "${merge(
    map("Name", format("%s-%s", var.service, var.environment)),
    map("Environment", var.environment),
    map("Description", var.description),
    map("Service", var.service),
    var.tags
  )}"
}

resource "aws_elasticache_parameter_group" "kong" {
  name   = "${var.service}-${var.environment}"
  family = "redis4.0"

  description = "${var.description}"
}
