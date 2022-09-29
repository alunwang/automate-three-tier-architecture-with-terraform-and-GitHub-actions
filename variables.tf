# The count of items
variable "item_count" {
  type        = number
  default     = 2
  description = "The count of items used to set AZs, subnets, instances, ..."
}

# Region to use
variable "AWS_REGION" {
  type        = string
  default     = "eu-north-1"
  description = "The aws region to use"
}

# VPC variables
variable "vpc_cidr" {
  type        = string
  default     = "10.123.0.0/16"
  description = "Default VPC cidr block"
}
variable "dev_azs" {
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
  description = "The availability zones used for dev"
}
variable "web_subnet_cidr" {
  type        = list(string)
  default     = ["10.123.128.0/24", "10.123.129.0/24"]
  description = "The cidr block used for web (public)"
}
variable "application_subnet_cidr" {
  type        = list(string)
  default     = ["10.123.1.0/24", "10.123.2.0/24"]
  description = "The cidr block used for application (private)"
}
variable "database_subnet_cidr" {
  type        = list(string)
  default     = ["10.123.64.0/24", "10.123.65.0/24"]
  description = "The cidr block used for database (private)"
}


# Instance variables
variable "ami_id" {
  type        = string
  default     = "ami-078e13ebe3b027f1c"
  description = "The default ami used"
}
variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "The default instance type used"
}

# varaibles for datbase
variable "rds_instance" {
  type = map(any)
  default = {
    allocated_storage   = 10
    engine              = "mysql"
    engine_version      = "8.0.28"
    instance_class      = "db.t3.micro"
    multi_az            = false
    db_name             = "mysqldb"
    skip_final_snapshot = true
  }
}

variable "user_info" {
  type = map(any)
  default = {
    username = "alan"
    password = "Abigale55"
  }
  sensitive = true
}



