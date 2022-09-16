# #a single instance example
# resource "aws_instance" "example" {
#   ami = "ami-02f3416038bdb17fb" #changed ubuntu image with latest
#   instance_type = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.instance.id]

# #Terraform's 'heredoc' syntax, allows to create multiline strings w/o /n chars
# #Run a simple webserver on port 8080 (busybox tool default installed on Ubuntu)
#   user_data = <<-EOF
#     #!/bin/bash
#     echo "Hello, World" > index.html
#     nohup busybox httpd -f -p ${var.server_port} & 
#     EOF

#   tags = {
#     Name = "terraform-example"
#   }
# }

#by default aws does not allow traffic to/from EC2
#security group needed:
resource "aws_security_group" "instance" {
  name="${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instance.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}


#create a launch config for Auto Scaling Group (params similar to aws_instance):
resource "aws_launch_configuration" "example" {
  image_id = "ami-02f3416038bdb17fb" #same as the one from aws_instance resource
  instance_type = var.instance_type
  security_groups = [aws_security_group.instance.id]
  # Updated 'user_data' parameter with templatefile function:
  user_data = templatefile("${path.module}/user-data.sh", 
  {
    server_port = var.server_port
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
  })

# Terraform's 'heredoc' syntax, allows to create multiline strings w/o /n chars
# Run a simple webserver on port 8080 (busybox tool default installed on Ubuntu)
# Also pulled database address and port out ofo the terraform_remote_state data source
  # user_data = <<EOF
  #   #!/bin/bash
  #   echo "Hello, World" > index.html
  #   echo "${data.terraform_remote_state.db.outputs.address}" >> index.html
  #   echo "${data.terraform_remote_state.db.ouputs.port}" >> index.html
  #   nohup busybox httpd -f -p ${var.server_port} & 
  #   EOF
}

# create the ASG itself:
resource "aws_autoscaling_group" "example" {
  # the ASG uses a reference to fill in the launch config name
  launch_configuration = aws_launch_configuration.example.name
  # finally pull the subnet IDs and tell you ASG to use those subnets, via the following argument:
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key = "Name"
    value = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }
}

# we need subnet_ids - tells the ASG which VPC subnets to use for the EC2 instances
# each subnet lives in an isolated AWS AZ (deploy across diff subnets for best availability)
# better than hard-coding (won't be maintainbale/portable) => Use data sources to get list of subnets
# data sources represent pieces of read-only info fetched from the provider:
data "aws_vpc" "default" {
  default = true # tells tf to look for the default VPC in the AWS account
  # to get the VPC id, use: data.aws_vpc.default.id
}

# aws_subnet_ids deprecated and replaced by aws_subnets
# combine with another vpc data source to look up the subnets within that VPC:
data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}


# multiple servers, each with own IP => need to offer users a single IP to connect => Load Balancer
# create the ALB (Application Load Balancer):
resource "aws_lb" "example" {
  name = "${var.cluster_name}-alb-asg"
  load_balancer_type = "application"
  subnets = data.aws_subnets.default.ids
  security_groups = [aws_security_group.alb.id] #added after creating sg resource
}

#define a listener for the ALB:
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = local.http_port 
  protocol = "HTTP"

  #by default, return a simple 404 page (for requests that don't match any listener rules)
  default_action{
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found. Oh no..."
      status_code = 404
    }
  }
}

#OBS: by default all aws resources (including ALBs) don't allow any traffic => need new SG:
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-sg-alb"

  #Allow inbound HTTP requests (changed it as resource)
  # ingress {
  #   from_port = local.http_port 
  #   to_port = local.http_port 
  #   protocol = local.tcp_protocol
  #   cidr_blocks = local.all_ips
  # }

  # Allow all outbound requests (changed it as resource)
  # so the load balancer can perform health checks, will be configured
  # egress {
  #   from_port = local.any_port
  #   to_port = local.any_port
  #   protocol = local.any_protocol
  #   cidr_blocks = local.all_ips
  # }
}

#Allow inbound HTTP requests
resource "aws_security_group_rule" "allow_http_inbound" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port = local.http_port 
  to_port = local.http_port 
  protocol = local.tcp_protocol
  cidr_blocks = local.all_ips  
}

resource "aws_security_group_rule" "allow_all_outbound" {
  type = "egress"
  security_group_id = aws_security_group.alb.id

  from_port = local.any_port
  to_port = local.any_port
  protocol = local.any_protocol
  cidr_blocks = local.all_ips 
}


#create a target group that ALB uses for ASG:
resource "aws_lb_target_group" "asg"{
  name     = "tf-${var.cluster_name}-lb-tg"
  port     = 8080 #here is where redirection from 80 to 8080 takes place
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

#tie the previous pieces together by creating listener rules:
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# Read remote MySQL db tf state data
data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key #era stage/data-storage/mysql/terraform.tfstate
    region = "us-east-2"
  } 
}
# All the database’s output variables are stored in the state file and you can read them 
# from the terraform_remote_state data source using an attribute reference of the form:
# data.terraform_remote_state.<NAME>.outputs.<ATTRIBUTE>


# !! this is how template_file was used, we now use templatefile function instead !!
# The template_file data source has two arguments: template, which is a string to render, 
# and vars, which is a map of variables to make available while rendering. 
# It has one output attribute called rendered, which is the result of rendering template, 
# including any interpolation syntax in template, with the variables available in vars.
# data "template_file" "user_data" {
#   template = file("user-data.sh")
#   vars = {
#     server_port = var.server_port
#     db_address = data.terraform_remote_state.db.outputs.address
#     db_port = data.terraform_remote_state.db.outputs.port
#   }
# }
