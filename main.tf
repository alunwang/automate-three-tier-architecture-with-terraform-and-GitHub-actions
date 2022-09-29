/*
 * Define 1 VPC for all resources
 */
resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "dev"
  }
}

/*
 * Define public subnets for web
 */
resource "aws_subnet" "web_subnet" {
  count                   = var.item_count
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.web_subnet_cidr[count.index]
  map_public_ip_on_launch = true
  availability_zone       = var.dev_azs[count.index]

  tags = {
    Name = "dev-web_subnet-${count.index}"
  }
}

/*
 * Define private subnets for application
 */
resource "aws_subnet" "application_subnet" {
  count                   = var.item_count
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.application_subnet_cidr[count.index]
  map_public_ip_on_launch = false
  availability_zone       = var.dev_azs[count.index]

  tags = {
    Name = "dev-app-subnet-${count.index}"
  }
}

/*
 * Define private subnets for database
 */
resource "aws_subnet" "database_subnet" {
  count                   = var.item_count
  vpc_id                  = aws_vpc.dev_vpc.id
  cidr_block              = var.database_subnet_cidr[count.index]
  map_public_ip_on_launch = false
  availability_zone       = var.dev_azs[count.index]

  tags = {
    Name = "dev_db-subnet-${count.index}"
  }
}

# An internet Gateway
resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

# A route table
resource "aws_route_table" "dev_web_rt" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "dev_web_rt"
  }
}

# Create a default route for public subnet to route to internet gateway
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.dev_web_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dev_igw.id
}

# Create subnet association with route table
resource "aws_route_table_association" "dev_rt_association" {
  count          = var.item_count
  subnet_id      = aws_subnet.web_subnet[count.index].id
  route_table_id = aws_route_table.dev_web_rt.id
}

# Create a security group for web
resource "aws_security_group" "dev_web_sg" {
  name        = "dev_web_sg"
  description = "Allow HTTP ingress traffic on port 80"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description = "HTTP request from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow requests from anywhere
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # allow requests to anywhere
  }

  tags = {
    Name = "dev_web_sg"
  }
}

# Create a security group for application
resource "aws_security_group" "dev_webserver_sg" {
  name        = "dev_webserver_sg"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description     = "Allow traffic from web layer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.dev_web_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev_webserver_sg"
  }
}

/*
 * Define a launch configruation
 */
resource "aws_launch_configuration" "dev_launch_conf" {
  name_prefix     = "dev_launch_conf-"
  image_id        = var.ami_id
  instance_type   = var.instance_type
  user_data       = file("install_apache.sh")
  security_groups = [aws_security_group.dev_webserver_sg.id]

  lifecycle {
    create_before_destroy = true
  }
}

/*
 * Define a autoscaling group
 */
resource "aws_autoscaling_group" "dev_asg" {
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 1
  health_check_grace_period = 100
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.dev_launch_conf.name
  vpc_zone_identifier       = [aws_subnet.web_subnet[0].id, aws_subnet.web_subnet[1].id]

  lifecycle {
    ignore_changes = [
      desired_capacity, target_group_arns
    ]
  }
}

/*
 * Define a scaling down policy
 */
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "dev_scale_down"
  autoscaling_group_name = aws_autoscaling_group.dev_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}
resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_description   = "Monitors CPU utilization for ASG"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  alarm_name          = "dev_scale_down_alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "10"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.dev_asg.name
  }
}

/*
# Create EC2 instances
resource "aws_instance" "webserver" {
  count                  = var.item_count
  ami                    = var.ami_id
  instance_type          = var.instance_type
  availability_zone      = var.dev_azs[count.index]
  vpc_security_group_ids = [aws_security_group.dev_webserver_sg.id]
  subnet_id              = aws_subnet.web_subnet[count.index].id
  user_data              = file("install_apache.sh")

  tags = {
    Name = "Web server ${count.index}"
  }
}
*/


# Create a security group for database
resource "aws_security_group" "dev_database_sg" {
  name        = "dev_database_sg"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.dev_webserver_sg.id]
  }
  egress {
    from_port   = 32768 # Why? is it a must???
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev_database_sg"
  }
}
#Create a database
resource "aws_db_subnet_group" "dev_db_subnet_group" {
  name       = "dev_db_subnet_group"
  subnet_ids = [aws_subnet.database_subnet[0].id, aws_subnet.database_subnet[1].id]

  tags = {
    Name = "dev database subnet group"
  }
}
resource "aws_db_instance" "dev_db" {
  allocated_storage      = var.rds_instance.allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.dev_db_subnet_group.id
  engine                 = var.rds_instance.engine
  engine_version         = var.rds_instance.engine_version
  instance_class         = var.rds_instance.instance_class
  multi_az               = var.rds_instance.multi_az
  skip_final_snapshot    = var.rds_instance.skip_final_snapshot
  vpc_security_group_ids = [aws_security_group.dev_database_sg.id]
  db_name                = var.rds_instance.db_name
  username               = var.user_info.username
  password               = var.user_info.password
}






# Create an Application load balancer
resource "aws_lb" "dev_external_alb" {
  name               = "dev-external-alb" # Why cannot used "_"
  internal           = false              # internet facing not internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dev_web_sg.id]
  subnets            = [aws_subnet.web_subnet[0].id, aws_subnet.web_subnet[1].id]
}

/*
 * Define a target group
 */
resource "aws_lb_target_group" "dev_external_tg" {
  name     = "dev-external-tg" # Why cannot used "_"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.dev_vpc.id
}
/*
resource "aws_lb_target_group_attachment" "dev_tg_attachment" {
  count            = var.item_count
  target_group_arn = aws_lb_target_group.dev_external_tg.arn
  target_id        = aws_instance.webserver[count.index].id
  port             = 80
}
*/
resource "aws_autoscaling_attachment" "dev_tg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.dev_asg.id
  lb_target_group_arn    = aws_lb_target_group.dev_external_tg.arn
}

/*
 * Define a listener on alb
 * Listen HTTP traffic from port 80.
 * And by default forward them to a target group.
 */
resource "aws_lb_listener" "dev_alb_istener" {
  load_balancer_arn = aws_lb.dev_external_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev_external_tg.arn
  }
}
