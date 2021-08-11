#!/bin/bash

export IMAGE=${INPUT_IMAGE:-"$GITHUB_REPOSITORY"}
export IMAGE_TAG="$(echo $INPUT_IMAGE_TAG | cut -c1-16 )"
export APPLICATION=${INPUT_APPLICATION:-"$(echo $IMAGE | cut -d/ -f2)"}
export REGISTRY="10.228.0.240:5000"

export REGISTRY_USER="docker"
export REGISTRY_PASSWORD=${INPUT_REGISTRY_PASSWORD:-$GITHUB_TOKEN}
export DOCKERHUB_AUTH="$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)"
export CONTEXT_PATH=${INPUT_CONTEXT_PATH}

export DEPLOYMENT_REPO=${INPUT_DEPLOYMENT_REPO}
export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN}

export EXTRA_ARGS=${INPUT_EXTRA_ARGS}

mkdir -p $HOME/.docker/

cat <<EOF >$HOME/.docker/config.json
{
        "insecure-registries" : ["$REGISTRY"]
        "auths": {
                "$REGISTRY": {
                        "auth": "${DOCKERHUB_AUTH}"
                }
        }
}
EOF

export CONTEXT="$CONTEXT_PATH"
export DOCKERFILE="--file $CONTEXT_PATH/${INPUT_DOCKERFILE}"
export DESTINATION="--tag ${REGISTRY}/${IMAGE}:${IMAGE_TAG}"
export ARGS="--push $DESTINATION $DOCKERFILE $CONTEXT"

echo "$ARGS"

echo "Building image"

buildx build $ARGS || exit 1

echo "Cloning deployment repo"

export ENVIRONMENT=${INPUT_ENVIRONMENT}
export YAML_FILE=/deployment-repo/applications/$APPLICATION/$ENVIRONMENT/${INPUT_YAML_FILE}
export YAML_FILE_IMAGE_TAG_KEY=${INPUT_YAML_FILE_IMAGE_TAG_KEY}

echo "ENVIRONMENT: $ENVIRONMENT"

git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO /deployment-repo
yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG} || exit 1

cd /deployment-repo
git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"
git add "${YAML_FILE}"
git commit -m "chore(${APPLICATION}): bumping ${ENVIRONMENT} image tag"
git push
