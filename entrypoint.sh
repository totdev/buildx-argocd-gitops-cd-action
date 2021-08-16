#!/bin/bash

export IMAGE=${INPUT_IMAGE:-"$GITHUB_REPOSITORY"}

echo "DEPLOYMENT_REPO_TOKEN: $DEPLOYMENT_REPO_TOKEN"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"


export IMAGE_TAG="$(echo $INPUT_IMAGE_TAG | cut -c1-16 )"
export APPLICATION=${INPUT_APPLICATION:-"$(echo $IMAGE | cut -d/ -f2)"}
export REGISTRY="10.228.0.240:5000"
echo "IMAGE: $IMAGE"
echo "IMAGE_TAG: $IMAGE_TAG"
echo "INPUT_IMAGE_TAG: $INPUT_IMAGE_TAG"

export REGISTRY_USER="docker"
export REGISTRY_PASSWORD=${INPUT_REGISTRY_PASSWORD}
export DOCKERHUB_AUTH="$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)"
export CONTEXT_PATH=${INPUT_CONTEXT_PATH}

export DEPLOYMENT_REPO=${INPUT_DEPLOYMENT_REPO}
export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN:-"$GITHUB_TOKEN"}

export EXTRA_ARGS=${INPUT_EXTRA_ARGS}

mkdir -p $HOME/.docker/

cat <<EOF >$HOME/.docker/config.json
{
        "insecure-registries" : ["$REGISTRY"],
        "auths": {
                "$REGISTRY": {
                        "auth": "$DOCKERHUB_AUTH"
                }
        }
}
EOF

#echo -n "$REGISTRY_PASSWORD" | docker login "$REGISTRY" -u docker --password-stdin

export CONTEXT="$CONTEXT_PATH"
export DOCKERFILE="--file $CONTEXT_PATH/${INPUT_DOCKERFILE}"
export DESTINATION="--tag ${REGISTRY}/${IMAGE}:${IMAGE_TAG}"
export ARGS="--push $DESTINATION $DOCKERFILE $CONTEXT"

#echo "$ARGS"

echo "Building image"

buildx build $ARGS || exit 1

echo "Cloning deployment repo"

export ENVIRONMENT=${INPUT_ENVIRONMENT}
export YAML_FILE=applications/deployments/$APPLICATION/$ENVIRONMENT/${INPUT_YAML_FILE}
export YAML_FILE_IMAGE_TAG_KEY=${INPUT_YAML_FILE_IMAGE_TAG_KEY}

echo "ENVIRONMENT: $ENVIRONMENT"

echo "DEPLOYMENT REPO: $DEPLOYMENT_REPO"

echo "DEPLOYMENT REPO TOKEN: $DEPLOYMENT_REPO_TOKEN"

echo "ENVIRONMENT: $ENVIRONMENT"

echo "YAML_FILE: $YAML_FILE"

echo "YAML_FILE_IMAGE_TAG_KEY: $YAML_FILE_IMAGE_TAG_KEY"

echo "git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO /deployment-repo"

echo "yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG}"

#mkdir -p /deployment-repo

git clone https://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@github.com/totdev/applications || exit 1

#git clone https://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@github.com/$DEPLOYMENT_REPO /deployment-repo || exit 1
#yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG} || exit 1


#cd /deployment-repo
yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG} || exit 1

#applications/deployments/n381-api/production/kustomization.yaml

git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"
git add "${YAML_FILE}"
git commit -m "chore(${APPLICATION}): bumping ${ENVIRONMENT} image tag"
git push
