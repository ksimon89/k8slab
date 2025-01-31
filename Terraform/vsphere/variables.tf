// define vsphere variables

variable "vsphere_server" {
  type = string
}
variable "vsphere_user" {
  type      = string
  sensitive = true
}
variable "vsphere_password" {
  type      = string
  sensitive = true
}

