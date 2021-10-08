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

variable "backend_tls" {
  type    = bool
  default = true
}

variable "template_tags" {
  type    = list(string)
  default = []
}
