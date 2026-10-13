# Variables de entrada (valores por defecto)

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-west-2"
}

variable "zona" {
  description = "Letra de la zona de disponibilidad dentro de la región"
  type        = string
  default     = "b"
}

variable "proyecto" {
  description = "Nombre del proyecto"
  type        = string
  default     = "tienda"
}

variable "ambiente" {
  description = "Ambiente (dev, lab, prod...)"
  type        = string
  default     = "lab"
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}
