variable "aws_access_key" {
    default = "xxxxxxxxxxxxxxxxxxxxxxx"
    description = "user aws access key"
}
variable "aws_secret_key" {
    default = "yyyyyyyyyyyyyyyyyyyyyyyyyy"
    description = " user aws secret key"
}
variable "aws_region" {
    default = "us-west-2"
    description = "Region name"
}
variable "web_ami" {
    default = "ami-01fee56b22f308154"
    description = "Which amazon machine image"
}
variable "lcb_key" {
    default = "lcb-key"
}
variable "vpc_fullcidr" {
    default = "10.0.0.0/16"
    description = "the vpc cdir"
}
variable "rds_mysql_engine" {
    default = "mysql"
    description = "DB Type"
}
variable "rds_mysql_version" {
    default = "5.7"
    description = "DB Version"
}
variable "rds_mysql_instance_class" {
    default = "db.t2.large"
    description = "DB Machine class"
}
variable "rds_mysql_username" {
    default = "root"
    description = "MySQL DB username"
}
variable "rds_mysql_password" {
    default = "xxxxxxxxxxxxxxxxxxx"
    description = "MySQL DB password"
}
