# For Keys Continutous Provisioning

This is the manual set up and update of the Cloud Build for the provisioning of the infrastructure via terraform.

## Manual setup 

 * This assumes you have set up a [terraform SA](../terraform/README.md).
 * Adjust the `substitutions` to match your needs. Complete list found in [cloudbuild.yaml](./cloudbuild.yaml):L123.
 * Execute the following with a CLI session in `experimental/cloudbuild` folder to set up triggers:
```
gcloud beta builds triggers create github \
  --trigger-config=./continuous-validation.yaml

gcloud beta builds triggers create github \
  --trigger-config=./continuous-provisioning.yaml
```