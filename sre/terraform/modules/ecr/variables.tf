variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["backend"]
}

variable "image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to keep per repository"
  type        = number
  default     = 10
}

variable "untagged_expire_days" {
  description = "Days before untagged images expire"
  type        = number
  default     = 7
}

variable "github_actions_role_arns" {
  description = "List of GitHub Actions IAM role ARNs that can push/pull images"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
