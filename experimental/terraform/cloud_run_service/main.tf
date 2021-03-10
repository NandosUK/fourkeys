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

resource "google_cloud_run_service" "default" {
  location = var.google_region
  name     = var.service_name
  project  = var.google_project_id

  autogenerate_revision_name = true

  metadata {
    namespace = var.google_project_id
    labels = {
      creator = "terraform"
    }
  }
  
  template {
    spec {
      containers {
        image = var.container_image_path
        env {
          name  = "PROJECT_NAME"
          value = var.google_project_id
        }
      }
      service_account_name = var.service_account_email
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    null_resource.app_container,
  ]

  lifecycle {
    ignore_changes = [
      metadata["labels"] # to stop terraform changing location.
    ]
  }

}

resource "google_cloud_run_domain_mapping" "default" {
  count = var.fqdn == null ? 0 : 1

  location = var.google_region
  name     = var.fqdn
  project  = var.google_project_id

  metadata {
    namespace = var.google_project_id
    annotations = {
      "creator" = "terraform"
    }
  }

  spec {
    route_name = google_cloud_run_service.default.name
  }
}

resource "google_cloud_run_service_iam_binding" "noauth" {
  location = google_cloud_run_service.default.location
  project  = google_cloud_run_service.default.project
  service  = google_cloud_run_service.default.name

  role = "roles/run.invoker"
  members = var.invokers
}

resource "null_resource" "app_container" {
  provisioner "local-exec" {
    # build container using Dockerfile
    command = "gcloud builds submit ${var.container_source_path} --tag=${var.container_image_path} --project=${var.google_project_id}"
  }
}