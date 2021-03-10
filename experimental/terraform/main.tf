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

terraform {
  required_version = ">= 0.14"
}

locals {
  choosen_parsers = setunion(var.version_control_systems, var.ci_cd_systems)
  parsers = {
    github : {
      source : "../../bq_workers/github_parser"
      topic : "GitHub-Hookshot"
      subscription : "GithubSubscription"
    }
    gitlab : {
      source : "../../bq_workers/gitlab_parser"
      topic : "Gitlab"
      subscription : "GitlabSubscription"
    },
    cloud-build : {
      source : "../../bq_workers/cloud_build_parser"
      topic : "cloud-builds"
      subscription : "CloudBuildSubscription"
    },
    tekton : {
      source : "../../bq_workers/tekton_parser"
      topic : "Tekton"
      subscription : "TektonSubscription"
    }
  }
  tables = [
    {
      name : "changes"
      schema : "../../setup/changes_schema.json"
      schedule_query : "../../queries/changes.sql"
    },
    {
      name : "deployments"
      schema : "../../setup/deployments_schema.json"
      schedule_query : "../../queries/deployments.sql"
    },
    {
      name : "events_raw"
      schema : "../../setup/events_raw_schema.json"
      time_partition : {
        field : "time_created"
        type : "DAY"
      }
    },
    {
      name : "incidents"
      schema : "../../setup/incidents_schema.json"
      schedule_query : "../../queries/incidents.sql"
    }
  ]
}

# [START: pub/sub]
resource "google_service_account" "for_cloud_run_pubsub_invoker" {
  account_id   = "cloud-run-pubsub-invoker"
  display_name = "Cloud Run Pub/Sub Invoker"
  project      = var.google_project_id
}

module "pubsub" {
  for_each = toset(local.choosen_parsers)

  source  = "terraform-google-modules/pubsub/google"
  version = "~> 1.8"

  topic      = local.parsers[each.key].topic
  project_id = var.google_project_id
  push_subscriptions = [
    {
      name                       = local.parsers[each.key].subscription                       // required
      push_endpoint              = module.cloud_run_for_parsers[each.key].url                 // required
      oidc_service_account_email = google_service_account.for_cloud_run_pubsub_invoker.email  // optional
    }
  ]
  subscription_labels = {
    creator = "terraform"
  }
}
# [END: pub/sub]

# [START: cloud run]
data "google_container_registry_repository" "default" {
  project  = var.google_project_id
  region   = var.google_artifact_location
}
# Create storage bucket in desired region to overcome cloud run bug
resource "google_storage_bucket" "cloudbuild" {
  count = lower(regex("^[a-zA-Z]+", var.google_region)) == "us" ? 0 : 1

  force_destroy = true
  location      = var.google_region
  name          = "${var.google_project_id}_cloudbuild"
  project       = var.google_project_id

  labels = {
    creator = "terraform"
  }
}

module "service_accounts_for_event_handler" {
  source        = "terraform-google-modules/service-accounts/google"
  version       = "~> 3.0"

  project_id    = var.google_project_id
  names         = [ "event-handler" ]
  project_roles = [
    "${var.google_project_id}=>roles/pubsub.publisher",
    "${var.google_project_id}=>roles/secretmanager.secretAccessor",
  ]
}

module "cloud_run_for_event_handler" {
  source                = "./cloud_run_service"

  container_image_path  = "${data.google_container_registry_repository.default.repository_url}/event-handler"
  container_source_path = "../../event_handler"
  fqdn                  = var.event_handler_fqdn
  google_project_id     = var.google_project_id
  google_region         = var.google_region
  service_account_email = module.service_accounts_for_event_handler.email
  service_name          = "event-handler"

  providers = {
    google = google
  }

  depends_on = [
    google_storage_bucket.cloudbuild,
  ]
}

module "service_accounts_for_parsers" {
  source        = "terraform-google-modules/service-accounts/google"
  version       = "~> 3.0"

  project_id    = var.google_project_id
  names         = [ "parser-handler" ]
  project_roles = [
    "${var.google_project_id}=>roles/bigquery.dataOwner",
    "${var.google_project_id}=>roles/pubsub.subscriber",
  ]
}

module "cloud_run_for_parsers" {
  for_each = toset(local.choosen_parsers)
  
  source                = "./cloud_run_service"

  container_image_path  = "${data.google_container_registry_repository.default.repository_url}/${each.key}-parser"
  container_source_path = local.parsers[each.key].source
  google_project_id     = var.google_project_id
  google_region         = var.google_region
  invokers              = [ "serviceAccount:${google_service_account.for_cloud_run_pubsub_invoker.email}" ]
  service_account_email = module.service_accounts_for_parsers.email
  service_name          = "${each.key}-parser"

  providers = {
    google = google
  }

  depends_on = [
    google_storage_bucket.cloudbuild,
  ]
}
# [END: cloud run]

# [START: BigQuery]
resource "google_bigquery_dataset" "default" {
  dataset_id    = "four_keys"
  friendly_name = "Four Keys Metrics"
  location      = var.google_region
  project       = var.google_project_id

  labels = {
    creator = "terraform"
  }
}

resource "google_bigquery_table" "defaults" {
  for_each = { for item in local.tables : item.name => item if contains(keys(item), "time_partition") == false}

  dataset_id    = google_bigquery_dataset.default.dataset_id
  friendly_name = "For Keys ${title(each.key)}"
  project       = var.google_project_id
  table_id      = each.key

  labels = {
    creator = "terraform"
  }

  schema = file(each.value.schema)
}

resource "google_bigquery_table" "time_partitions" {
  for_each = { for item in local.tables : item.name => item if contains(keys(item), "time_partition") }

  dataset_id    = google_bigquery_dataset.default.dataset_id
  friendly_name = "For Keys ${title(each.key)}"
  project       = var.google_project_id
  table_id      = each.key

  dynamic "time_partitioning" {
    for_each = [ each.value.time_partition ]
    content {
      field = time_partitioning.value.field
      type  = time_partitioning.value.type
    }
  }

  labels = {
    creator = "terraform"
  }

  schema = file(each.value.schema)
}

resource "google_bigquery_data_transfer_config" "defaults" {
  for_each = { for item in local.tables : item.name => item.schedule_query if contains(keys(item), "schedule_query") }

  display_name           = "four_keys_scheduled_${each.key}_query"
  location               = var.google_region
  data_source_id         = "scheduled_query"
  schedule               = "every 24 hours"
  destination_dataset_id = google_bigquery_dataset.default.dataset_id
  params = {
    destination_table_name_template = try(google_bigquery_table.defaults[each.key].table_id, google_bigquery_table.time_partitions[each.key].table_id)
    write_disposition               = "WRITE_TRUNCATE"
    query                           = file(each.value)
  }
}
# [END: BigQuery]

# [END: Secret Manager]
resource "google_secret_manager_secret" "event_handler" {
  secret_id = "event-handler"

  labels = {
    creator = "terraform"
  }

  replication {
    user_managed {
      replicas {
        location = var.google_region
      }
    }
  }
}
resource "random_id" "secret" {
  byte_length = 20
}

resource "google_secret_manager_secret_version" "event_handler" {
  secret = google_secret_manager_secret.event_handler.id

  secret_data = random_id.secret.hex
}
# [END: Secret Manager]
