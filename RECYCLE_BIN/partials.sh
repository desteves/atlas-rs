
cd /Users/d/github/desteves/atlas-rs/terraform


export TF_VAR_atlas_project_id=671822b16da2717cd63d86a5
export MONGODB_ATLAS_PUBLIC_KEY=wqzzxrug # atlas puk
export MONGODB_ATLAS_PRIVATE_KEY=80562c37-4cef-4970-860a-719196545a62 # atlas pik
export TF_VAR_gcp_project_id=diana-438818
gcloud auth application-default login
gcloud config set project $TF_VAR_gcp_project_id
gcloud services enable storage.googleapis.com run.googleapis.com cloudfunctions.googleapis.com cloudbuild.googleapis.com



terraform init
# Terraform has been successfully initialized!
terraform plan
terraform apply
# Apply complete! ...


# cluster_name = "global-rs"
# demo_api_urls = {
#   "au" = "https://atlas-rs-demo-au-vud27cynqa-ts.a.run.app"
#   "us" = "https://atlas-rs-demo-us-vud27cynqa-ue.a.run.app"
# }
# demo_effective_mongodb_uri = <sensitive>
# demo_site_urls = {
#   "au" = "https://storage.googleapis.com/atlas-rs-greetings-au/index.html"
#   "us" = "https://storage.googleapis.com/atlas-rs-greetings-us/index.html"
# }
# project_id = "671822b16da2717cd63d86a5"
# standard_connection_string = <sensitive>

gcloud run services add-iam-policy-binding atlas-rs-demo-au --region=australia-southeast1 --member="allUsers" --role="roles/run.invoker"
gcloud run services add-iam-policy-binding atlas-rs-demo-us --region=us-central1 --member="allUsers" --role="roles/run.invoker"


# Verify IAM on the functions:
gcloud functions get-iam-policy atlas-rs-demo-us --region=us-central1 --gen2
gcloud functions get-iam-policy atlas-rs-demo-au --region=australia-southeast1 --gen2
Ensure roles/cloudfunctions.invoker includes allUsers
Curl test:
curl -i https://<us-func-url>/latest
curl -i -H "Origin: https://storage.googleapis.com" https://<us-func-url>/latest
Expect 200 and Access-Control-Allow-Origin: *