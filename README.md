# QR-CODE-GENERATOR

Lab instruction and tasks:

- Overview
- Setup and Requirements
- Task 1. Containerize Application with Docker
- Task 2. Build CI/CD Pipeline with GitHub Actions
- Task 3. Deploy Docker Image with Kubernetes
- Task 4. Configure Container Monitoring with Ops Agent

## Overview

## Setup and Requirements

In the following steps you will:

- Install Docker and Ops Agent 
- Clone the application source code from GitHub 
- Create and configure AWS S3 bucket 
- Run the application source code locally (Optional)
- Troubleshooting the "unable to locate credentials" error

### Install tools

- Linux development essentials
- Docker
- Cloud Logging Agent or Ops Agent

```bash
#!/bin/bash

# Install development tools for the kernel
apt-get update
apt-get install -yq ca-certificates git build-essential

# Install Docker packages
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Cloud Logging Agent
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &

# Install Ops Agent on individual VMs
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
```

references:

- https://www.cloudskillsboost.google/focuses/11952?parent=catalog#step7
- https://docs.docker.com/engine/install/debian/
- https://cloud.google.com/stackdriver/docs/solutions/agents/ops-agent/installation

### Clone the source code

This sample application generates QR Codes for the provided URL, the front-end is in NextJS and the API is written in Python using FastAPI.

```
git clone https://github.com/rishabkumar7/devops-qr-code/tree/main
```

### [Create and configure AWS S3 bucket](https://stackoverflow.com/questions/36272286/getting-access-denied-when-calling-the-putobject-operation-with-bucket-level-per)

create an AWS IAM user:

- create a new user within the AWS IAM console
- grant the `AmazonS3FullAccess` permission to the created user

generate an access key:

- generate a new access key id and secret access key as the created user
- store these credentials securely, as they will be used for subsequent configurations

create an AWS S3 bucket:

- create a new S3 bucket within the AWS S3 console
- configure the bucket with the following settings:
    - object ownership: `object writer`
    - block public access settings for this bucket:
        - `block public access to buckets and objects granted through new public bucket or access point policies`
        - `block public and cross-account access to buckets and objects through any public bucket or access point policies`

configure environment variables:

- modify the `api/.env` file with the generated credentials and name of the created bucket

references:

- https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html

### [Run locally](https://github.com/rishabkumar7/devops-qr-code) (Optional)

api:

- navigate into the `api` directory: `cd api`
- create a virtual environment: `python -m venv .venv`
- activate the virtual environment: `.venv\Scripts\activate`
- install the required packages: `pip install -r requirements.txt`
- run the `api` server: `uvicorn main:app --reload`
- your `api` server should be running on uvicorn default port: `http://localhost:8000`

frontend:

- navigate into the `frontend` directory: `cd frontend`
- install the dependencies: `npm install`
- run the `frontend` server: `npm run dev`
- your `frontend` server should be running on port 3000: `http://localhost:3000`

### [Fix "unable to locate credentials"](https://stackoverflow.com/questions/33297172/boto3-error-botocore-exceptions-nocredentialserror-unable-to-locate-credential)

```python
import os

s3 = boto3.resource('s3', aws_access_key_id=os.getenv("AWS_ACCESS_KEY"), aws_secret_access_key=os.getenv("AWS_SECRET_KEY"))
bucket_name = os.getenv("AWS_BUCKET_NAME")

s3.Bucket(bucket_name).put_object(Key=file_name, Body=img_byte_arr, ContentType='image/png', ACL='public-read')
```

## Task 1. Containerize Application with Docker

Containerize both the front-end and API by creating Dockerfiles.

In the following steps you will:

- Create Dockerfiles:
    - Initialize Docker assets to containerize `api`, a Python application.
    - Initialize Docker assets to containerize `frontend`, a Node.js based application.
    - Use multi-stage builds in the `frontend` Dockerfile to execute `npm run build` during the Docker build process.

- Build and Deploy Docker Images: (Optional)
    - Create a `.env` file to store the AWS secrets as environment variables.
    - Create a Docker Compose file to build the Docker images from Dockerfiles and to pass the environmental variables to the `backend` container.
    - Create a NGINX container as HTTP reverse proxy to allow browser-based application `frontend` to fetch URL by container name `backend`.
    - Reconfigure the `frontend` source code to make HTTP request to `backend` through the proxy.
    - Reconfigure the `api` source code to allow CORS from `frontend` through the proxy.
    - Run the Docker containers to deploy both `frontend`, `backend`, and `proxy` services in a shared Docker network.

### [Create a Dockerfile for Python](https://docs.docker.com/language/python/containerize/)

You can use Docker Desktop's built-in Docker Init feature to help streamline the process, or you can manually create the assets. [Use Docker Init]

If you don't have Docker Desktop installed or prefer creating the assets manually, you can create the following files in your project directory. [Manually create assets]

#### Use Docker Init

```
docker init
Welcome to the Docker Init CLI!

This utility will walk you through creating the following files with sensible defaults for your project:
  - .dockerignore
  - Dockerfile
  - compose.yaml
  - README.Docker.md

Let's get started!

? What application platform does your project use? Python
? What version of Python do you want to use? 3.11.4
? What port do you want your app to listen on? 8000
? What is the command to run your app? python3 -m uvicorn app:app --host=0.0.0.0 --port=8000
```

#### Manually create assets

Create a file named `Dockerfile` with the following contents.

```
# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG PYTHON_VERSION=3.11.4
FROM python:${PYTHON_VERSION}-slim AS base

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Create a non-privileged user that the app will run under.
# See https://docs.docker.com/go/dockerfile-user-best-practices/
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.cache/pip to speed up subsequent builds.
# Leverage a bind mount to requirements.txt to avoid having to copy them into
# into this layer.
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=bind,source=requirements.txt,target=requirements.txt \
    python -m pip install -r requirements.txt

# Switch to the non-privileged user to run the application.
USER appuser

# Copy the source code into the container.
COPY . .

# Expose the port that the application listens on.
EXPOSE 8000

# Run the application.
CMD python3 -m uvicorn app:app --host=0.0.0.0 --port=8000
```

Create a file named `.dockerignore` with the following contents.

```
# Include any files or directories that you don't want to be copied to your
# container here (e.g., local build artifacts, temporary files, etc.).
#
# For more help, visit the .dockerignore file reference guide at
# https://docs.docker.com/go/build-context-dockerignore/

**/.DS_Store
**/__pycache__
**/.venv
**/.classpath
**/.dockerignore
**/.env
**/.git
**/.gitignore
**/.project
**/.settings
**/.toolstarget
**/.vs
**/.vscode
**/*.*proj.user
**/*.dbmdl
**/*.jfm
**/bin
**/charts
**/docker-compose*
**/compose.y*ml
**/Dockerfile*
**/node_modules
**/npm-debug.log
**/obj
**/secrets.dev.yaml
**/values.dev.yaml
LICENSE
README.md
```

#### Modify the Entrypoint (Important)

```
CMD python3 -m uvicorn main:app --host=0.0.0.0 --port=8000
```

### [Create a Dockerfile for Node.js](https://docs.docker.com/language/nodejs/containerize/)

You can use Docker Desktop's built-in Docker Init feature to help streamline the process, or you can manually create the assets. [Use Docker Init]

If you don't have Docker Desktop installed or prefer creating the assets manually, you can create the following files in your project directory. [Manually create assets]

#### Use Docker Init

Inside the `frontend` directory, run the `docker init` command. `docker init` provides some default configuration, but you'll need to answer a few questions about your application. For example, this application uses FastAPI to run. Refer to the following example to answer the prompts from `docker init` and use the same answers for your prompts.

```
docker init
Welcome to the Docker Init CLI!

This utility will walk you through creating the following files with sensible defaults for your project:
  - .dockerignore
  - Dockerfile
  - compose.yaml
  - README.Docker.md

Let's get started!

? What application platform does your project use? Node
? What version of Node do you want to use? 18.0.0
? Which package manager do you want to use? npm
? What command do you want to use to start the app: node src/index.js
? What port does your server listen on? 3000
```

#### Manually create assets

Create a file named `Dockerfile` with the following contents.

```
# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/

# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

ARG NODE_VERSION=18.0.0

FROM node:${NODE_VERSION}-alpine

# Use production node environment by default.
ENV NODE_ENV production


WORKDIR /usr/src/app

# Download dependencies as a separate step to take advantage of Docker's caching.
# Leverage a cache mount to /root/.npm to speed up subsequent builds.
# Leverage a bind mounts to package.json and package-lock.json to avoid having to copy them into
# into this layer.
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

# Run the application as a non-root user.
USER node

# Copy the rest of the source files into the image.
COPY . .

# Expose the port that the application listens on.
EXPOSE 3000

# Run the application.
CMD node src/index.js
```

Create a file named `.dockerignore` with the following contents.

```
# Include any files or directories that you don't want to be copied to your
# container here (e.g., local build artifacts, temporary files, etc.).
#
# For more help, visit the .dockerignore file reference guide at
# https://docs.docker.com/go/build-context-dockerignore/

**/.classpath
**/.dockerignore
**/.env
**/.git
**/.gitignore
**/.project
**/.settings
**/.toolstarget
**/.vs
**/.vscode
**/.next
**/.cache
**/*.*proj.user
**/*.dbmdl
**/*.jfm
**/charts
**/docker-compose*
**/compose.y*ml
**/Dockerfile*
**/node_modules
**/npm-debug.log
**/obj
**/secrets.dev.yaml
**/values.dev.yaml
**/build
**/dist
LICENSE
README.md
```

### [Use multi-stage builds for Next.js](https://github.com/vercel/next.js/tree/canary/examples/with-docker)

To add support for Docker to an existing microservice, just copy the `Dockerfile` into the root of your microservice `frontend` and add the following to the `frontend/next.config.js` file:

```js
module.exports = {
  // ... rest of the configuration.
  output: "standalone",
};
```

#### `Dockerfile`

```Dockerfile
ARG NODE_VERSION=20.16.0

FROM node:${NODE_VERSION}-alpine AS base


FROM base AS deps

RUN apk add --no-cache libc6-compat
WORKDIR /app

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci


FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build


FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD HOSTNAME="0.0.0.0" node server.js
```

### Build the Docker images (Optional)

#### Create a Docker Compose file

```yaml
services:
  backend:
    build: ./api
    ports:
      - 8000:8000
    environment:
      - AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
      - AWS_SECRET_KEY=${AWS_SECRET_KEY}
      - AWS_BUCKET=${AWS_BUCKET}

  frontend:
    build: ./frontend
    ports:
      - 3000:3000
    environment:
      - NODE_ENV=production
```

#### Create a configuration file `.env` for AWS secrets

```
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
AWS_BUCKET=
```

#### [Create a HTTP reserve proxy](https://stackoverflow.com/questions/77060233/unknown-host-error-calling-containerized-backend-from-frontend)

Create a HTTP reverse proxy

```
# nginx/default.conf

server {
  listen 80;
  server_name localhost;
  
  location / {
    proxy_pass http://frontend:3000/;
  }

  location /api/ {
    proxy_pass http://api:8000/;
  }
}
```

Create a NGINX container with minimal configuration

```Dockerfile
# nginx/Dockerfile

FROM nginx:1.25
COPY default.conf /etc/nginx/conf.d
```

Add the container to the Docker Compose file

```
services:
  api:
    build: ./api
    ports:
      - 8000:8000
    environment:
      - AWS_ACCESS_KEY=${AWS_ACCESS_KEY}
      - AWS_SECRET_KEY=${AWS_SECRET_KEY}
      - AWS_BUCKET=${AWS_BUCKET}
    networks:
      - my-network

  frontend:
    build: ./frontend
    ports:
      - 3000:3000
    environment:
      - NODE_ENV=production
    networks:
      - my-network
  
  nginx:
    build: ./nginx
    ports: 
      - 80:80
    networks:
      - my-network

networks:
  my-network:
```

#### Establish communication between containers with NGINX proxy

```js
const response = await axios.post(`/api/generate-qr/?url=${url}`);
```

```python
origins = [
    "/"
]
```

#### Run the Docker Compose file

1. Run the application in the background:
    ```
    docker compose up --build -d
    ```
2. Access the application:
    - If you're r
    unning Docker on your local machine, you can access the application at http://localhost.
    - If you're running Docker on a remote server, you can access the application at http://<server_ip_address>.
3. Test the API:
    - Click **Generate QR Code**. You should see a QR code image below the button.
4. Stop the application:
    ```
    docker compose down
    ```

## Task 2. Build CI/CD Pipeline with GitHub Actions

Write a CI/CD pipeline to automate the deployment of the containers once your source code is changed. Use tools like GitHub Actions or Azure DevOps.

In the following steps you will:

Create the repository:

- Create a Google Artifact Registry repository to store the Docker images.
- Create a Workload Identity Federation through service account to authenticate GitHub Actions to Google Cloud.

Set up the workflow:

- Configure a starter GitHub Actions workflow that build a Docker container and publish it to Google Artifact Registry.
- Refactor the workflow to adapt the micorservices architecture.

Run the workflow:

- Create GitHub secrets to pass the Workload Identity Federation credentials to the workflow.
- Reconfigure the workflow environmental variables to specify the Google Artifact Registry repository.
- Make changes to the `VERSION` files to trigger the workflow.


### [Create a Artifact Registry repository](https://cloud.google.com/artifact-registry/docs/docker/store-docker-container-images#create)

1. [Open the Repositories page](https://console.cloud.google.com/artifacts?_ga=2.30121535.127365739.1723438346-1686645962.1716954818&_gac=1.47401557.1723199436.CjwKCAjw_Na1BhAlEiwAM-dm7C_0TOAn-2BXgSX3JtwLJvIA1SflbalwcVhnEvgok6gofSM0OQaTlRoCM7gQAvD_BwE) in the Google Cloud console.
2. Click **+ Create Repository**.
3. Specify `qr-code-generator` as the repository name.
4. Choose **Docker** as the format and **Standard** as the mode.
5. Under Location Type, select **Region** and then choose any location. This information is used by the workflow that will be configured later as `GAR_LOCATION`.
6. Click **Create**.

### [Create a Workload Identity Federation](https://github.com/google-github-actions/auth)

There are three ways to authenticate to Google Cloud from GitHub Actions:

- (Preferred) Direct Workload Identity Federation
- **Workload Identity Federation through a Service Account**
- (Least Preferred) Service Account Key JSON

Direct Workload Identity Federation is preferred since it directly authenticates GitHub Actions to Google Cloud without a proxy resource. However, not all Google Cloud resources support `principalSet` identities, and the resulting token has a maximum lifetime of 10 minutes. 

Service Account Key JSON is least preferred since it has underlying security concerns. Google Cloud Service Account Key JSON files must be secured and treated like a password. Anyone with access to the JSON key can authenticate to Google Cloud as the underlying Service Account. By default, these credentials never expire, which is why the former authentication options are much preferred.

#### Usage

```yaml
jobs:
  job_id:
    # Add "id-token" with the intended permissions.
    permissions:
      contents: 'read'
      id-token: 'write'

    steps:
    - uses: 'actions/checkout@v4'

    - uses: 'google-github-actions/auth@v2'
      with:
        service_account: '${{ secrets.WIF_SERVICE_ACCOUNT }}' # my-service-account@my-project.iam.gserviceaccount.com
        workload_identity_provider: '${{ secrets.WIF_PROVIDER }}' # "projects/123456789/locations/global/workloadIdentityPools/github/providers/my-repo"
```

#### Inputs: Workload Identity Federation and generating OAuth 2.0 access tokens

- `workload_identity_provider`: (Required) The full identifier of the Workload Identity Provider, including the project number, pool name, and provider name. If provided, this must be the full identifier which includes all parts:

    ```
    projects/123456789/locations/global/workloadIdentityPools/my-pool/providers/my-provider
    ```

- `service_account`: (Required) Email address or unique identifier of the Google Cloud service account for which to generate the access token. For example:

    ```
    my-service-account@my-project.iam.gserviceaccount.com
    ```

- `token_format`: (Required) This value must be `"access_token"` to generate OAuth 2.0 access tokens.

- `access_token_lifetime`: (Optional) Desired lifetime duration of the access token, in seconds. This must be specified as the number of seconds with a trailing "s" (e.g. 30s). The default value is 1 hour (3600s). 

#### Setup

These instructions use the `gcloud` command-line tool. See 

```shell
export PROJECT_ID=my-project # TODO
export GITHUB_ORG=my-github-org # TODO
export SERVICE_ACCOUNT_NAME=actions-artifact-registry 

# 1. Create a Google Cloud Service Account:

gcloud iam service-accounts create $SERVICE_ACCOUNT \
  --project="${PROJECT_ID}"

# 2. Create a Workload Identity Pool:

gcloud iam workload-identity-pools create "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 3. Get the full ID of the Workload Identity Pool:

export WORKLOAD_IDENTITY_POOL_ID=$(
gcloud iam workload-identity-pools describe "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)")

export REPO="${GITHUB_ORG}/qr-code-generator"

# 4. Create a Workload Identity Provider in that pool:

gcloud iam workload-identity-pools providers create-oidc "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="My GitHub repo Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 5. Allow authentications from the Workload Identity Pool to your Google Cloud Service Account:

gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"

# 6. Grant the Google Cloud Service Account permissions to access Artifact Registry:

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

### [Configure a starter workflow](https://docs.github.com/en/actions/writing-workflows/using-starter-workflows)

1. On GitHub.com, navigate to the main page of the repository. For example:
    ```
    https://github.com/yunchengwong-org/qr-code-generator
    ```
2. Click **Actions**.
3. Search for keywords: `Artifact Registry`

    Found 1 workflow
    ```
    Build and Deploy to Cloud Run
    By Google Cloud

    Build a Docker container, publish it to Google Artifact Registry, and deploy to Google Cloud Run.
    ```
4. Click `Configure`.
5. Click `Commit changes...`.

### [Refactor the workflow](https://www.learncloudnative.com/blog/2020-02-20-github-action-build-push-docker-images)

To build and push the images if the `VERSION` file has changed:

```yaml
on:
  push:
    branches:
      - master
    paths:
      - '**/VERSION'
```

To loop through the folder that has VERSION file updated:

```yaml
- name: Build and Push Container
  run: |-
    for versionFilePath in $(git diff-tree --no-commit-id --name-only -r ${{ github.sha }} ${{ github.event.before }} | grep "VERSION");
    do
      FOLDER=$(versionFilePath%"/VERSION")
      SERVICE=${folder##*/}

      docker build -t "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.SERVICE }}:${{ github.sha }}" ./
      docker push "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.SERVICE }}:${{ github.sha }}"
    done;
```

To store multiple images in the same Google Artifact Repository:

```yaml
- name: Build and Push Container
  run: |-
    docker build -t "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/qrcodegenerator/${{ env.SERVICE }}:${{ github.sha }}" ./
    docker push "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/qrcodegenerator/${{ env.SERVICE }}:${{ github.sha }}"
```

To fetch all commits with `diff-tree`, change the default value of `fetch-depth`:

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

#### `.github/workflows/main.yml`

```yaml
name: Build and Push to Artifact Registry

on:
  push:
    branches: [ "main" ]

env:
  PROJECT_ID: ${{ secrets.PROJECT_ID }}
  GAR_LOCATION: us-central1 # TODO: update Artifact Registry region
  GAR_REPO: qrcodegenerator # TODO: update Artifact Registry repository name

jobs:
  build:
    # Add 'id-token' with the intended permissions for workload identity federation
    permissions:
      contents: 'read'
      id-token: 'write'

    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Google Auth
        id: auth
        uses: 'google-github-actions/auth@v2'
        with:
          token_format: 'access_token'
          workload_identity_provider: '${{ secrets.WIF_PROVIDER }}' # e.g. - projects/123456789/locations/global/workloadIdentityPools/github/providers/my-repo
          service_account: '${{ secrets.WIF_SERVICE_ACCOUNT }}' # e.g. - my-service-account@my-project.iam.gserviceaccount.com

      # BEGIN - Docker auth and build (NOTE: If you already have a container image, these Docker steps can be omitted)

      # Authenticate Docker to Google Cloud Artifact Registry
      - name: Docker Auth
        id: docker-auth
        uses: 'docker/login-action@v1'
        with:
          username: 'oauth2accesstoken'
          password: '${{ steps.auth.outputs.access_token }}'
          registry: '${{ env.GAR_LOCATION }}-docker.pkg.dev'

      - name: Build and Push Container
        run: |-
          for versionFilePath in $(git diff-tree --no-commit-id --name-only -r ${{ github.sha }} ${{ github.event.before }} | grep "VERSION");
          do
            FOLDER=$(versionFilePath%"/VERSION")
            IMAGE_NAME=${folder##*/}
            
            docker build -t "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPO }}/$IMAGE_NAME:${{ github.sha }}" --file "$FOLDER/Dockerfile" $FOLDER
            docker push "${{ env.GAR_LOCATION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.GAR_REPO }}/$IMAGE_NAME:${{ github.sha }}"
          done;

      # END - Docker auth and build
```

### [Create GitHub secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)

Repository secrets:

| Name                | Value                                                                                                   |
|---------------------|---------------------------------------------------------------------------------------------------------|
| PROJECT_ID          | my-project-123456-a7                                                                                    |
| WIF_PROVIDER        | projects/123456789/locations/global/workloadIdentityPools/github/providers/my-repo                      |
| WIF_SERVICE_ACCOUNT | my-service-account@my-project.iam.gserviceaccount.com                                                   |

### Reconfigure GitHub variables

TODO:

- GAR_LOCATION
- GAR_REPO

### [Run the workflow](https://docs.docker.com/language/nodejs/configure-ci-cd/)

1. Make changes to `api/VERSION` and/or `frontend/VERSION`. 
    
    For example:
    ```
    1
    ```
2. Push the changes to GitHub.

    After pushing the commit, the workflow starts automatically.
    ```
    git add .
    git commit -m "Run the workflow"
    git push
    ```
3. Go to the Actions tab. It displays the workflow.
    
    Selecting the workflow shows you the breakdown of all the steps.
4. When the workflow is complete, go to your [repositories on Google Artifact Repository](https://console.cloud.google.com/artifacts?_ga=2.236730625.127365739.1723438346-1686645962.1716954818&_gac=1.85076331.1723199436.CjwKCAjw_Na1BhAlEiwAM-dm7C_0TOAn-2BXgSX3JtwLJvIA1SflbalwcVhnEvgok6gofSM0OQaTlRoCM7gQAvD_BwE).
    
    If you see the new repository in that list, it means the GitHub Actions successfully pushed the image to Google Artifact Repository.

## Task 3. Deploy Docker Image with Kubernetes

Create deployment and service YAML files for both the Next.js front-end and the FastAPI backend. Set up a Kubernetes service within your cloud provider (Azure AKS, Amazon EKS, or GCP GKE).

From the previous tasks, you have:

- Containerize your microservices each in a separate container with its dependencies
- Push the Docker images to Google Artifact Registry

| Service  | Docker Image             | Description                                      |
|----------|--------------------------|--------------------------------------------------|
| api      | qrcodegenerator/api      | Generates QR code and upload to AWS S3 bucket.   |
| frontend | qrcodegenerator/frontend | Submits users' input to the api service.         |
| proxy    | nginx                    | Routes traffic to the api and frontend services. |

In the following steps you will:

- Create a public GKE standard cluster
- Create deployments, one for each service.
- Create internal services for the `frontend` and `api` deployments and an external service for the `proxy` deployment.
- 

command-line tool `kubectl`
- Expose the microservices internally wit default service type Cluster IP
- Create a Ingress controller of NGINX as HTTP reverse proxy
- Expose the frontend deployment with a `LoadBalancer`


- Test 

- Add monitoring
- Create a ConfigMap to share data

### Create a GKE cluster

### Create deployment and expose with Cluster IP

ClusterIP (internal) -- the default type means that this Service is only visible inside of the cluster,

```
kubectl create -f deployments/api.yaml
kubectl create -f services/api.yaml

kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml
```

### Create ConfigMap to store NGINX path-based routing config then create external service loadbalancer

So what just happened? Behind the scenes Kubernetes created an external Load Balancer with a public IP address attached to it. Any client who hits that public IP address will be routed to the pods behind the service. In this case that would be the nginx pod.

LoadBalancer adds a load balancer from the cloud provider which forwards traffic from the service to Nodes within it.

```
kubectl create configmap nginx-proxy-conf --from-file=nginx/proxy.conf
kubectl create -f deployments/proxy.yaml
kubectl create -f services/proxy.yaml
```

### Interact with the microservices

1. View the running containers
2. Retrieve the external IP address of the proxy service with the following command:
```
kubectl get services proxy
```
Example output:
```
```
3. Visit the external IP to access the frontend container


## Task 4. Configure Container Monitoring with Ops Agent

Set up monitoring for containers to track key metrics and insights. Use Azure Monitor for AKS, Amazon CloudWatch Container Insights for EKS, or Grafana for advanced monitoring.