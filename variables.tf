
variable "region" {
  description = "Region to provision in"
  type        = string
}

variable "server_name" {
  description = "Name of the server"
  type        = string
}

variable "public_key" {
  description = "Public ssh key for instances"
  type        = string
}

variable "domains" {
  description = "Domains for your server"
  type        = list(any)
}
