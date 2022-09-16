# public_ip of single instance example
# output "public_ip" {
#   value = aws_instance.example.public_ip
#   description = "The public IP address of the single instance example web server"
# }


output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"  
}

output "asg_name" {
  value = aws_autoscaling_group.example.name
  description = "the name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
  description = "The ID of the Security Group attached to the load balancer"
}

# using templatefile function instead of template_file data source
# output "template" {
#   value = templatefile("user-data.sh", 
#   {
#     server_port = var.server_port
#     db_address = data.terraform_remote_state.db.outputs.address
#     db_port = data.terraform_remote_state.db.outputs.port
#   })
# }