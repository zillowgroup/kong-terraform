data "template_file" "cloud-init" {
  template = "${file("cloud-init.cfg")}"
}

data "template_file" "shell-script" {
  template = "${file("cloud-init.sh")}"

  vars {
    REGION         = "${var.aws_region}"
    PARAMETER_PATH = "/${var.service}/${var.environment}"
    DB_USER        = "${replace(format("%s_%s", var.service, var.environment), "-", "_")}"
  }
}

data "template_cloudinit_config" "cloud-init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = "${data.template_file.cloud-init.rendered}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.shell-script.rendered}"
  }
}
