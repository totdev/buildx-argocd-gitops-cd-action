#!/bin/bash

export IMAGE=${INPUT_IMAGE:-"$GITHUB_REPOSITORY"}

echo "IMAGE: $IMAGE"
echo "GITHUB_REPOSITORY: $GITHUB_REPOSITORY"
echo "INPUT_IMAGE_TAG: $INPUT_IMAGE_TAG"

export IMAGE_TAG="$(echo $INPUT_IMAGE_TAG | cut -c1-16 )"
export APPLICATION=${INPUT_APPLICATION:-"$(echo $IMAGE | cut -d/ -f2)"}
export REGISTRY="10.228.0.240:5000"

export REGISTRY_USER="docker"
export REGISTRY_PASSWORD=${INPUT_REGISTRY_PASSWORD}
export DOCKERHUB_AUTH="$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)"
export CONTEXT_PATH=${INPUT_CONTEXT_PATH}

export DEPLOYMENT_REPO=${INPUT_DEPLOYMENT_REPO}
#export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN:-"$GITHUB_TOKEN"}
export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN}

echo "INPUT_DEPLOYMENT_REPO: $INPUT_DEPLOYMENT_REPO"
echo "DEPLOYMENT_REPO: $DEPLOYMENT_REPO"
echo "INPUT_DEPLOYMENT_REPO_TOKEN: $INPUT_DEPLOYMENT_REPO_TOKEN"
echo "GITHUB_TOKEN: $GITHUB_TOKEN"
echo "APPLICATIONS_REPO_TOKEN: $APPLICATIONS_REPO_TOKEN"
echo "DEPLOYMENT_REPO_TOKEN: $DEPLOYMENT_REPO_TOKEN"


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
export YAML_FILE=$HOME/deployment-repo/applications/deployments/$APPLICATION/$ENVIRONMENT/${INPUT_YAML_FILE}
export YAML_FILE_IMAGE_TAG_KEY=${INPUT_YAML_FILE_IMAGE_TAG_KEY}


#echo "git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO /deployment-repo"
#echo "yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG}"


#mv $HOME/deployment-repo $HOME/deployment-repo_old

git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO $HOME/deployment-repo || exit 1


echo "YAML_FILE: $YAML_FILE"
echo "YAML_FILE_IMAGE_TAG_KEY: $YAML_FILE_IMAGE_TAG_KEY"
echo "IMAGE_TAG: $IMAGE_TAG"

#yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG} || exit 1

#applications/deployments/n381-api/production/kustomization.yaml

cd $HOME/deployment-repo
#yq w -i ${YAML_FILE} ${YAML_FILE_IMAGE_TAG_KEY} ${IMAGE_TAG} || exit 1
git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"
#git add "${YAML_FILE}"
#git commit -m "chore(${APPLICATION}): bumping ${ENVIRONMENT} image tag"
#git push
