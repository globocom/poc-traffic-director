variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type = string
}

variable "vpc_project" {
  type = string
}

variable "subnet" {
  type = string
}

variable "backend1_host" {
  type = string
}

variable "backend2_host" {
  type = string
}

variable "template_tags" {
  type    = list(string)
  default = []
}

variable "backend1_percent" {
  type    = number
  default = 80
}

variable "backend2_percent" {
  type    = number
  default = 20
}

variable "ssl_certificate_id" {
  type    = string
  default = ""
}
