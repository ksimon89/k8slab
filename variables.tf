// define vsphere variables

variable "REMOVED_SERVER" {
  type = string
}
variable "REMOVED_USER" {
  type      = string
  sensitive = true
}
variable "REMOVED_PASSWORD" {
  type      = string
  sensitive = true
}

