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

output "url" {
  value = google_cloud_run_service.default.status[0]["url"]
}

output "location" {
  value = google_cloud_run_service.default.location
}

output "project" {
  value = google_cloud_run_service.default.project
}

output "name" {
  value = google_cloud_run_service.default.name
}

output "dns" {
  value = try(google_cloud_run_domain_mapping.default[0], null)
}
