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

variable "container_source_path" {
  type = string
}

variable "container_image_path" {
  type = string
}

variable "fqdn" {
  description = "(Optional) Mapped custom fully qualified domain name"
  default     = null
  type        = string
}
variable "google_project_id" {
  type = string
}
variable "google_region" {
  type = string
}

variable "invokers" {
  default     = [ "allUsers" ]
  description = "(Optional) list of users, groups, service accounts that can invoke cloud run service"
  type        = list(string)
}

variable "service_name" {
  type = string
}

variable "service_account_email" {
  default = null
  type    = string
}