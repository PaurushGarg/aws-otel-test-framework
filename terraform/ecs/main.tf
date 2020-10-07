module "common" {
  source = "../common"

  data_emitter_image = var.data_emitter_image
  aoc_image_repo = var.aoc_image_repo
  aoc_version = var.aoc_version
}

module "basic_components" {
  source = "../basic_components"
}

provider "aws" {
  region  = var.region
}

## create a ecs cluster, and give this cluster a unique name in case concurrent creating.
variable "ecs_cluster_name_prefix" {
  default = "aoc-integ-test"
}

module "ecs_cluster" {
  source  = "infrablocks/ecs-cluster/aws"
  version = "3.0.0"

  cluster_name = "${var.ecs_cluster_name_prefix}-${module.common.testing_id}"
  component = "important-component"
  deployment_identifier = "testing"
  vpc_id = module.basic_components.aoc_vpc_id
  subnet_ids = module.basic_components.aoc_private_subnet_ids
  region = var.region
  associate_public_ip_addresses = "yes"
  security_groups = [module.basic_components.aoc_security_group_id]
  cluster_desired_capacity = 1
}

## upload otconfig to ssm parameter store
data "template_file" "otconfig" {
  template = file(var.otconfig_path)

  vars = {
    region = var.region
    otel_service_namespace = module.common.otel_service_namespace
    otel_service_name = module.common.otel_service_name
    testing_id = module.common.testing_id
  }
}
resource "aws_ssm_parameter" "otconfig" {
  name = "otconfig-${module.common.testing_id}"
  type = "String"
  value = data.template_file.otconfig.rendered
}

## create task def
data "template_file" "task_def" {
  template = file(var.ecs_taskdef_path)

  vars = {
    region = var.region
    aoc_image = module.common.aoc_image
    data_emitter_image = module.common.aoc_emitter_image
    testing_id = module.common.testing_id
    otel_service_namespace = module.common.otel_service_namespace
    otel_service_name = module.common.otel_service_name
    ssm_parameter_arn = aws_ssm_parameter.otconfig.name
    sample_app_container_name = module.common.sample_app_container_name
    sample_app_listen_address = "${module.common.sample_app_listen_address_ip}:${module.common.sample_app_listen_address_port}"
  }
}

# debug
output "rendered" {
  value = data.template_file.task_def.rendered
}

resource "aws_ecs_task_definition" "aoc" {
  family = "aoc-task-def"
  container_definitions = data.template_file.task_def.rendered
  network_mode = "awsvpc"
  requires_compatibilities = ["EC2", "FARGATE"]
  cpu = 256
  memory = 512

  # simply use one role for task role and execution role,
  # we could separate them in the future if
  # we want to limit the permissions of the roles
  task_role_arn = module.basic_components.aoc_iam_role_arn
  execution_role_arn = module.basic_components.aoc_iam_role_arn
}

## create elb
resource "aws_lb" "aoc_lb" {
  # don't do lb if there's no sample app image
  count = var.data_emitter_image != "" ? 1 : 0

  # use public subnet to make the lb accessible from public internet
  subnets = module.basic_components.aoc_public_subnet_ids
  security_groups = [module.basic_components.aoc_security_group_id]
  name = "aoc-lb-${module.common.testing_id}"
}

resource "aws_lb_target_group" "aoc_lb_tg" {
  # don't do lb if there's no sample app image
  count = var.data_emitter_image != "" ? 1 : 0

  name = "aoc-lbtg-${module.common.testing_id}"
  port = module.common.sample_app_listen_address_port
  protocol = "HTTP"
  target_type = "ip"
  vpc_id = module.basic_components.aoc_vpc_id

  health_check {
    path = "/"
    unhealthy_threshold = 10
    healthy_threshold = 2
    interval = 10
    matcher = "202,404"
  }
}

resource "aws_lb_listener" "aoc_lb_listener" {
  # don't do lb if there's no sample app image
  count = var.data_emitter_image != "" ? 1 : 0

  load_balancer_arn = aws_lb.aoc_lb[0].arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.aoc_lb_tg[0].arn
  }
}

## deploy
resource "aws_ecs_service" "aoc" {
  # don't do lb if there's no sample app image
  count = var.data_emitter_image != "" ? 1 : 0
  name = "aoctaskdef-${module.common.testing_id}"
  cluster = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.aoc.arn
  desired_count = 1
  launch_type = var.ecs_launch_type

  load_balancer {
    target_group_arn = aws_lb_target_group.aoc_lb_tg[0].arn
    container_name = module.common.sample_app_container_name
    container_port = module.common.sample_app_listen_address_port
  }

  network_configuration {
    subnets = module.basic_components.aoc_private_subnet_ids
    security_groups = [module.basic_components.aoc_security_group_id]
  }

  provisioner "local-exec" {
    working_dir = "../../"
    command = "${module.common.validator_path} --args='-c ${var.validation_config} -t ${module.common.testing_id} --region ${var.region} --metric-namespace ${module.common.otel_service_namespace}/${module.common.otel_service_name} --endpoint http://${aws_lb.aoc_lb[0].dns_name}'"
  }
}

# remove lb since there's no sample app, some test cases will drop in here, for example, ecsmetadata receiver test
resource "aws_ecs_service" "aoc_without_sample_app" {
  # don't do lb if there's no sample app image
  count = var.data_emitter_image == "" ? 1 : 0
  name = "aoc"
  cluster = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.aoc.arn
  desired_count = 1
  launch_type = var.ecs_launch_type

  network_configuration {
    subnets = module.basic_components.aoc_private_subnet_ids
    security_groups = [module.basic_components.aoc_security_group_id]
  }

  provisioner "local-exec" {
    working_dir = "../../"
    command = "${module.common.validator_path} --args='-c ${var.validation_config} -t ${module.common.testing_id} --region ${var.region} --metric-namespace ${module.common.otel_service_namespace}/${module.common.otel_service_name}'"
  }
}




