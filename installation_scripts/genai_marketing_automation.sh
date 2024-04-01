#!/bin/bash
#
# Performs an automated installation of the Generative AI for Marketing solution accelerator
# Modify the Globals variables prior to running this script
#################################

# Global variables
#################################
#PROJECT_ID="project-001"          # ID of the project where you want to deploy
#LOCATION="us-central1"            # Name of the region 
DATASET_NAME="genai_marketing"          # BigQuery Dataset Name for creation
SEARCH_APP_NAME="genai_marketing"       # Vertex Search App Name for creation
CHAT_BOT_NAME="genai_marketing"    # Vertex Conversation app Name for creation
#COMPANY_NAME="genai_marketing"          # Your company name 
EXISTING_LOOKER_URI=""            # your Existing Looker dashboard URl. leave it empty if you don't have
SERVICE_ACCOUNT="genai-markting-sa"    # Service account name for creation
#YOUR_DOMAIN="google.com"               # Your domain name. eg user@company.com then company.com 
GDRIVE_FOLDER_NAME="genai-marketing-assets"      # Google drive folder name for creation
#GDRIVE_PARENT_FOLDER_ID=""        # Google drive parent folder ID. Leave it empty if you don't have

# Do not modify below here

echo -e "\n"
bold=$(tput bold)
normal=$(tput sgr0)
echo -e "This script will automate the setup of the Generative AI for Marketing solution accelerator."
echo -e "Sign in to your Google Cloud account to continue."
gcloud auth login --no-launch-browser --quiet

echo -e "\n"
read -p "Enter Project ID: " PROJECT_ID
read -p "Enter Location (e.g. us-central1): " LOCATION
read -p "Enter Company Name: " COMPANY_NAME
read -p "Enter Your Domain Name (e.g. example.com): " YOUR_DOMAIN

# installing jq
if [ -n "$(command -v yum)" ]; then
   sudo yum update -y && sudo yum install jq -y
elif [ -n "$(command -v apt-get)" ]; then
   sudo apt-get update -y && sudo apt-get install jq -y
elif [ -n "$(command -v brew)" ]; then
   sudo brew update && sudo brew install jq
elif [ -n "$(command -v apk)" ]; then
   sudo apk update -y && sudo apk add jq
else
   echo "Package manager not found. Please install jq manually."
fi

gcloud config set project $PROJECT_ID   # Setting the Project in Gcloud
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"   # Do not modify this
SERVICE_ACCOUNT_CHECK=`gcloud iam service-accounts list --format=json | jq .[].email | grep "${SERVICE_ACCOUNT_EMAIL}" | wc -l`

if [[ SERVICE_ACCOUNT_CHECK -eq 0 ]]; then
    gcloud iam service-accounts create ${SERVICE_ACCOUNT} --display-name="${SERVICE_ACCOUNT}"
fi

if [ ! -f ../app/credentials.json ]; then
  gcloud iam service-accounts keys create ../app/credentials.json --iam-account=${SERVICE_ACCOUNT_EMAIL}
fi

echo -e "\n"
echo -e "Please create a folder in Google Drive and share the folder with the service account ${bold}${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com${normal} and set the permissions to 'Editor' for the service account."

echo -e "\n"
read -r -p "Have you created the folder and shared it with the service account? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        echo -e "\n"
        echo -e "Great! Let's proceed with the setup."
        read -p "Enter Folder ID of the Google Drive folder you just created: " GDRIVE_PARENT_FOLDER_ID
        ;;
    *)
        echo "!!!Please create the folder and share it with the service account before proceeding."
        exit 1
        ;;
esac 

gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/logging.logWriter" --condition=None
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/artifactregistry.reader" --condition=None
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/storage.objectViewer" --condition=None
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/appengine.appAdmin" --condition=None
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/appengine.appCreator" --condition=None
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/owner" --condition=None

gcloud auth activate-service-account --key-file=../app/credentials.json

echo -e "\n \n"
echo -e "Here are the names that will be used for creating resources \n"
echo -e "BIGQUERY DATASET_NAME: ${bold}${DATASET_NAME}${normal} \nSEARCH_APP: ${bold}${SEARCH_APP_NAME}${normal} \nCHAT_BOT_NAME: ${bold}${CHAT_BOT_NAME}${normal} \nSERVICE_ACCOUNT: ${bold}${SERVICE_ACCOUNT}${normal} \nGOOGLE_DRIVE_FOLDER_NAME: ${bold}${GDRIVE_FOLDER_NAME}${normal}"
echo -e "\nDo you wish to add postfix ? enter 1 for Yes and 2 for No"
echo -e "\n Note: If you are reruning the automation, use names like earlier"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) read -p "Enter Postfix: " POSTFIX
              DATASET_NAME="${DATASET_NAME}_${POSTFIX}"
              SEARCH_APP_NAME="${SEARCH_APP_NAME}_${POSTFIX}"
              CHAT_BOT_NAME="${CHAT_BOT_NAME}_${POSTFIX}"
              SERVICE_ACCOUNT="${SERVICE_ACCOUNT}_${POSTFIX}"
              GDRIVE_FOLDER_NAME="${GDRIVE_FOLDER_NAME}_${POSTFIX}"
              break ;;
        No ) echo "Using same names for setup"
             break ;;
    esac
done

# Enabling the services
echo -e "Enabling required apis..."
for service in "discoveryengine" "run" "cloudbuild" "compute" "cloudresourcemanager" "iam" "container" "cloudapis" "cloudtrace" "containerregistry" "iamcredentials" "dialogflow" "monitoring" "logging" "notebooks" "aiplatform" "storage" "datacatalog" "appengineflex" "translate" "admin" "docs" "drive" "sheets" "slides"
do
  gcloud services enable ${service}.googleapis.com --project=${PROJECT_ID} --quiet
done
echo -e "APIs are enabled."
sleep 3s

# Installing required packages
if [ -n "$(command -v yum)" ]; then
   sudo yum install python3 -y && sudo yum install python3-pip -y && sudo yum install jq -y && sudo yum install python3-venv -y
elif [ -n "$(command -v apt-get)" ]; then
   sudo apt-get install python3 -y && sudo apt-get install python3-pip -y && sudo apt-get install jq -y && sudo apt-get install python3-venv -y
elif [ -n "$(command -v brew)" ]; then
   sudo brew install python3 && sudo brew install python3-pip && sudo brew install jq && sudo brew install python3-venv
elif [ -n "$(command -v apk)" ]; then
   sudo apk add python3 && sudo apk add python3-pip && sudo apk add jq && sudo apk add python3-venv
else
   echo "Package manager not found. Please install python3, python3-pip and jq manually."
fi

if [ ! -d "../env" ]; then   # Checking the Virtualenv folder exists or not
   python3 -m venv ../env    # Creating virtualenv  
fi
source ../env/bin/activate   # activate Virtualenv

pip install -U pyarrow oauth2client google-api-core google-auth-httplib2 httplib2 googleapis-common-protos google-cloud-datacatalog google-cloud-storage google-cloud-bigquery numpy google-api-python-client google.cloud google.auth google-cloud-discoveryengine google-cloud-dialogflow-cx

# Updating the Project and Location details in app config and override files
sed -i "s|project_id = \"\"|project_id = '${PROJECT_ID}'|" ../app/app_config.toml
sed -i "s|location = \"us-central1\"|location = '${LOCATION}'|" ../app/app_config.toml
sed -i "s|project_id = \"\"|project_id = '${PROJECT_ID}'|" ../app/override.toml
sed -i "s|location = \"us-central1\"|location = '${LOCATION}'|" ../app/override.toml

# Copy the BigQuery template data to current directory 
if [ ! -d "../notebooks/aux_data" ]; then
   git clone https://github.com/aliakts/genai-for-marketing.git  # cloning the genai-for-marketing code from github
   cp -rf genai-for-marketing/notebooks/aux_data .
   rm -rf genai-for-marketing
else
    cp -rf ../notebooks/aux_data .
fi

#-----BigQuery Setup -----
python3 genai_marketing_env_setup.py $PROJECT_ID $LOCATION $DATASET_NAME

# Update the BigQuery Details in config files 
sed -i "s|dataset_id = \"\"|dataset_id = \"${DATASET_NAME}\"|g" ../app/app_config.toml
sed -i "s|dataset_id = \"\"|dataset_id = \"${DATASET_NAME}\"|g" ../app/override.toml
sed -i "s|tag_name = \"\"|tag_name = \"llmcdptemplate\"|g" ../app/app_config.toml
sed -i "s|tag_name = \"\"|tag_name = \"llmcdptemplate\"|g" ../app/override.toml


# gcloud auth application-default login
# gcloud auth application-default set-quota-project $PROJECT_ID

python3 genai_marketing_search_app_creation.py --project="${PROJECT_ID}" --app-name="${SEARCH_APP_NAME}" --company-name="${COMPANY_NAME}" --uris="cloud.goole.com/*"

SEARCH_DATASTORE_ID=`jq -r '.SEARCH_DATASTORE_ID' < marketingEnvValue.json`

sed -i "s|# datastores.<datastore ID> = 'default_config'|datastores.${SEARCH_DATASTORE_ID} = 'default_config'|g" ../app/app_config.toml
sed -i "s|datastores.example = 'default_config'|datastores.${SEARCH_DATASTORE_ID} = 'default_config'|g" ../app/override.toml

if [ -f credentials.json ]; then
   rm -rf credentials.json
fi

PROJECT_NUMBER=`gcloud projects describe $PROJECT_ID --format="value(projectNumber)"`     # Getting the project Number 
gcloud iam service-accounts keys create credentials.json --iam-account="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

export GOOGLE_APPLICATION_CREDENTIALS=credentials.json

#-----Google Drive Setup -----
python3 Create_GDrive_folder.py --folder_name="${GDRIVE_FOLDER_NAME}" --service_account_email="${SERVICE_ACCOUNT_EMAIL}" --parent_folder_id="${GDRIVE_PARENT_FOLDER_ID}"
python3 genai_marketing_conversation_app_creation.py --project="${PROJECT_ID}" --location="global" --app-name="${CHAT_BOT_NAME}" --company-name="${COMPANY_NAME}" --uris="support.google.com/google-ads/*" --datastore-storage-folder="gs://cloud-samples-data/gen-app-builder/search/alphabet-investor-pdfs/*"

CHAT_AGENT_ID=`jq -r '.AGENT_ENGINE_NAME' < marketingEnvValue.json | cut -d'/' -f6`
AGENT_LANGUAGE_CODE=`jq -r '.AGENT_LANGUAGE_CODE' < marketingEnvValue.json`

sed -i "s|  agent-id=\"\"|  agent-id=\"${CHAT_AGENT_ID}\"|g" ../app/app_config.toml
sed -i "s|  project-id=\"\"|  project-id=\"${PROJECT_ID}\"|g" ../app/app_config.toml
sed -i "s|  language-code=\"\"|  language-code=\"${AGENT_LANGUAGE_CODE}\"|g" ../app/app_config.toml

sed -i "s|  agent-id=\"\"|  agent-id=\"${CHAT_AGENT_ID}\"|g" ../app/override.toml
sed -i "s|  project-id=\"\"|  project-id=\"${PROJECT_ID}\"|g" ../app/override.toml
sed -i "s|  language-code=\"\"|  language-code=\"${AGENT_LANGUAGE_CODE}\"|g" ../app/override.toml

if [[ $EXISTING_LOOKER_URI != "" ]];then
   sed -i "s|dashboards.Overview = 'https://googledemo.looker.com/embed/dashboards/2131?allow_login_screen=true|dashboards.Overview = '${EXISTING_LOOKER_URI}'|" ../app/app_config.toml
   sed -i "s|dashboards.Overview = ''|dashboards.Overview = '${EXISTING_LOOKER_URI}'|" ../app/app_config.toml
fi

sed -i "s|domain = \"<YOUR DOMAIN>\"|domain = \"${YOUR_DOMAIN}\"|" ../app/override.toml

GDRIVE_FOLDER_ID=`jq -r '.GDRIVE_FOLDER_ID' < marketingEnvValue.json`
MarketingPptID=`jq -r '.MarketingPptID' < marketingEnvValue.json`
MarketingDocID=`jq -r '.MarketingDocID' < marketingEnvValue.json`
MarketingExcelID=`jq -r '.MarketingExcelID' < marketingEnvValue.json`

sed -i "s|drive_folder_id = ''|drive_folder_id = '${GDRIVE_FOLDER_ID}'|" ../app/app_config.toml
sed -i "s|slides_template_id = ''|slides_template_id = '${MarketingPptID}'|" ../app/app_config.toml
sed -i "s|doc_template_id = ''|doc_template_id = '${MarketingDocID}'|" ../app/app_config.toml
sed -i "s|sheet_template_id = ''|sheet_template_id = '${MarketingExcelID}'|" ../app/app_config.toml
sed -i "s|service_account: <REPLACE WITH YOUR SERVICE ACCOUNT ADDRESS>|service_account: '${PROJECT_NUMBER}-compute@developer.gserviceaccount.com'|" ../app.yaml
sed -i "s|service_account_json_key = '/credentials/credentials.json'|service_account_json_key = './credentials.json'|" ../app/app_config.toml
sed -i "s|service_account_json_key = \"\"|service_account_json_key = \"./credentials.json\"|" ../app/override.toml

#---override.toml---
sed -i "s|drive_folder_id = \"\"|drive_folder_id = \"${GDRIVE_FOLDER_ID}\"|" ../app/override.toml
sed -i "s|slides_template_id = \"\"|slides_template_id = \"${MarketingPptID}\"|" ../app/override.toml
sed -i "s|doc_template_id = \"\"|doc_template_id = \"${MarketingDocID}\"|" ../app/override.toml
sed -i "s|sheet_template_id = \"\"|sheet_template_id = \"${MarketingExcelID}\"|" ../app/override.toml


# Create a VPC network and subnet
VPC_NAME="genai-marketing-vpc"
SUBNET_NAME="genai-marketing-subnet"
REGION=$LOCATION  # Use the location provided by the user
FIREWALL_RULE_NAME="genai-marketing-allow-http"

VPC_EXISTS=$(gcloud compute networks list --filter="name=$VPC_NAME" --format="value(name)")

if [ -z "$VPC_EXISTS" ]
then
  gcloud compute networks create $VPC_NAME --subnet-mode=custom
fi

SUBNET_EXISTS=$(gcloud compute networks subnets list --filter="name=$SUBNET_NAME region:$REGION" --format="value(name)")

if [ -z "$SUBNET_EXISTS" ]
then
  gcloud compute networks subnets create $SUBNET_NAME --network=$VPC_NAME --region=$REGION --range=10.0.0.0/16
fi

gcloud compute firewall-rules create $FIREWALL_RULE_NAME --network=$VPC_NAME --allow tcp:80

cat >> ../app.yaml <<EOL

network:
  name: projects/${PROJECT_ID}/global/networks/${VPC_NAME}
  subnetwork_name: ${SUBNET_NAME}
EOL

#gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" --role="roles/appengine.appCreator" --condition=None

APP_ENGINE_CHECK=`gcloud app services list --filter="SERVICE: default" --format=json | jq .[].id | wc -l`
if [[ $APP_ENGINE_CHECK == 0 ]]
then
   gcloud app create --region=${LOCATION}
fi
cd .. && gcloud app deploy --quiet

gcloud projects remove-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/owner" --condition=None

# Revoke all accounts except service accounts
accounts=$(gcloud auth list --format="value(account)")

for account in $accounts
do
  if [[ ! $account == *".gserviceaccount.com" ]]
  then
    gcloud auth revoke $account --quiet
  fi
done

gcloud app browse --no-launch-browser