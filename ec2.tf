locals {
  tags = ["${null_resource.tags.*.triggers}"]
}

resource "null_resource" "tags" {
  count = "${length(keys(var.tags))}"

  triggers = "${map(
    "key", "${element(keys(var.tags), count.index)}",
    "value", "${element(values(var.tags), count.index)}",
    "propagate_at_launch", "true"
  )}"
}

resource "aws_launch_configuration" "kong" {
  name_prefix          = "${var.service}-${var.environment}-"
  image_id             = "${var.ec2_ami[data.aws_region.current.name]}"
  instance_type        = "${var.ec2_instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.kong.name}"
  key_name             = "${var.ec2_key_name}"

  security_groups = [
    "${data.aws_security_group.default.id}",
    "${aws_security_group.kong.id}",
  ]

  associate_public_ip_address = false
  ebs_optimized               = "${var.ec2_ebs_optimized}"
  enable_monitoring           = true
  placement_tenancy           = "default"
  user_data                   = "${data.template_cloudinit_config.cloud-init.rendered}"

  root_block_device {
    volume_size = "${var.ec2_root_volume_size}"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    "aws_rds_cluster.kong"
  ]
}

resource "aws_autoscaling_group" "kong" {
  name                = "${var.service}-${var.environment}"
  vpc_zone_identifier = ["${data.aws_subnet_ids.private.ids}"]

  launch_configuration = "${aws_launch_configuration.kong.name}"

  desired_capacity          = "${var.asg_desired_capacity}"
  force_delete              = false
  health_check_grace_period = "${var.asg_health_check_grace_period}"
  health_check_type         = "ELB"
  max_size                  = "${var.asg_max_size}"
  min_size                  = "${var.asg_min_size}"

  target_group_arns = ["${
    compact(
      concat(
        aws_alb_target_group.external.*.arn,
        aws_alb_target_group.internal.*.arn,
        aws_alb_target_group.internal-admin.*.arn,
        aws_alb_target_group.internal-gui.*.arn
      )
    )
  }"]

  tags = ["${concat(
      list(map(
        "key", "Name", 
        "value", format("%s-%s", var.service, var.environment), 
        "propagate_at_launch", true
      )),
      local.tags
  )}"]

  depends_on = [
    "aws_rds_cluster.kong"
  ]
}
