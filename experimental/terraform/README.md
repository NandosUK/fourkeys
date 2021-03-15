# Experimental Terraform setup

This folder contains terraform scripts to provision all of the infrastructure in a Four Keys GCP project. 

**DO NOT USE!** It's very early and very incomplete. (Though: holler if you want to contribute!)

Current functionality (2021-02-19):
- Create a GCP project (outside of terraform)
- Build the event-handler container image and push to GCR [TODO: use AR instead]
- Deploy the event-handler container as a Cloud Run service
- Omit the event-handler endpoint as an output
- Create and store webhook secret
- Create pubsub
- Set up BigQuery
- Build and deploy bigquery workers
- Establish BigQuery data transfer

TODO:
- Populate Data Studio dashboard
- (much else)

ALSO:
- provide user inputs for VCS system, CI/CD system, and GCP project settings

Open questions:
- What's an elegant way to support those user inputs (VCS, CI/CD) as conditionals in the TF?
- Should we use cloud build triggers to redeploy when the code changes rather than re-run the terraform?
- Cloud run domain mapping is supported in limited locations, should we support this at all?

Answered questions:
- Should we create the GCP project in terraform? No. The auth gets really complicated, especially when considering that the project may or may not be in an organization and/or folder
- This approach uses a service account and run TF as that, or keep the current process of using application default credentials of the user who invokes the script?

## Set Up

We recommend the use of [tfenv](https://github.com/tfutils/tfenv) to install and use the version defined in the code.

### Terraform Service Account

This code is set up to use a terraform service account with the least privileges to create the resources needed, therefore you will need to create one in your project (TODO: move to setup.sh):

```
gcloud init  # To select existing email and project
# The follow unset command clear any old credentials that may get in the way of impersonation
unset GOOGLE_OAUTH_ACCESS_TOKEN
unset GOOGLE_APPLICATION_CREDENTIALS
unset GOOGLE_CREDENTIALS
gcloud auth application-default login  # login as you to allow service account impersonation.
PROJECT_ID=$(gcloud config get-value project)
TF_SA_NAME=terraform
gcloud iam service-accounts create ${TF_SA_NAME} \
  --description "Infrastructure Provisioner" \
  --display-name "Terraform"
# grant service account permission to view Admin Project & Manage Cloud Storage
for ROLE in 'viewer' 'storage.admin' 'cloudbuild.builds.builder' 'run.admin' 'iam.serviceAccountUser' 'iam.serviceAccountAdmin' 'pubsub.admin' 'bigquery.admin' 'secretmanager.admin'; do
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${TF_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/${ROLE}
done

for API in 'cloudresourcemanager' 'compute' 'run' 'cloudbuild' 'pubsub' 'containerregistry' 'bigquery' 'bigquerydatatransfer' 'bigqueryconnection' 'secretmanager' 'iam'; do
  gcloud services enable "${API}.googleapis.com"
done
```
