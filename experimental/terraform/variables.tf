# Copyright 2020 Google LLC
# Copyright 2021 Nando’s Chickenland Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "event_handler_fqdn" {
  default     = null
  description = "(Optional) fully qualified domain name to be mapped as custom domain to the event handler cloud run service."
  type        = string
}

variable "git_hub_owner" {
  type = string
}

variable "git_hub_repository" {
  type = string
}

variable "google_artifact_location" {
  default = "us"
  type    = string
}
variable "google_project_id" {
  type = string
}
variable "google_project_number" {
  type = number
}
variable "google_region" {
  type = string
}

variable "version_control_systems" {
  description = "Supports github, gitlab"
  type        = list(string)
}

variable "ci_cd_systems" {
  description = "Supports cloud-build, tekton, gitlab"
  type        = list(string)
}
