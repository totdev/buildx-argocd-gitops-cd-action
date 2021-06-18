#!/bin/bash

export IMAGE=${INPUT_IMAGE}
export IMAGE_TAG=${INPUT_IMAGE_TAG:-"latest"}
export APPLICATION=${INPUT_APPLICATION:-"$(echo $IMAGE | cut -d/ -f2)"}

export IMAGE=$IMAGE:$IMAGE_TAG

export REGISTRY_USER=${INPUT_REGISTRY_USER}
export REGISTRY_PASSWORD=${INPUT_REGISTRY_PASSWORD}
export DOCKERHUB_AUTH="$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)"
export CONTEXT_PATH=${INPUT_CONTEXT_PATH}

export DEPLOYMENT_REPO=${INPUT_DEPLOYMENT_REPO}
export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN}

export EXTRA_ARGS=${INPUT_EXTRA_ARGS}

mkdir -p $HOME/.docker/

cat <<EOF >$HOME/.docker/config.json
{
        "auths": {
                "https://index.docker.io/v1/": {
                        "auth": "${DOCKERHUB_AUTH}"
                }
        }
}
EOF

export CONTEXT="$CONTEXT_PATH"
export DOCKERFILE="--file $CONTEXT_PATH/Dockerfile"
export DESTINATION="--tag igrowdigital/test"
export ARGS="--push $DESTINATION $DOCKERFILE $CONTEXT"

echo "$ARGS"

echo "Building image"

buildx build $ARGS

echo "Cloning deployment repo"

export ENVIRONMENT=${INPUT_ENVIRONMENT}
export VALUES_YAML=/deployment-repo/applications/$APPLICATION/$ENVIRONMENT/values.yaml
export VALUES_YAML_IMAGE_TAG_KEY=${INPUT_VALUES_YAML_IMAGE_TAG_KEY}

echo "ENVIRONMENT: $ENVIRONMENT"

git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO /deployment-repo
yq w -i ${VALUES_YAML} ${VALUES_YAML_IMAGE_TAG_KEY} ${IMAGE_TAG}

cd /deployment-repo
git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"
git add "${VALUES_YAML}"
git commit -m "chore(${APPLICATION}): bumping ${ENVIRONMENT} image tag"
git push
