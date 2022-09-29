output "alb_dns_name" {
  value       = "http://${aws_lb.dev_external_alb.dns_name}"
  description = "The DNS name of the Application Load Balancer"
}

output "asg_name" {
  value = aws_autoscaling_group.dev_asg.name
}
