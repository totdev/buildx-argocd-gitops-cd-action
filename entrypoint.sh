#!/bin/bash

export IMAGE=${INPUT_IMAGE:-"$GITHUB_REPOSITORY"}

export IMAGE_TAG="$(echo $INPUT_IMAGE_TAG | cut -c1-16 )"
export APPLICATION=${INPUT_APPLICATION:-"$(echo $IMAGE | cut -d/ -f2)"}

#export REGISTRY_USER="docker"
#export REGISTRY="harbor.cloud2.c3.furg.br"

export REGISTRY_USER="buildx"
export REGISTRY="servicos.c3.furg.br"

export IS_OPENFAAS_FN=${INPUT_IS_OPENFAAS_FN}

export REGISTRY_PASSWORD=${INPUT_REGISTRY_PASSWORD}
export DOCKERHUB_AUTH="$(echo -n $REGISTRY_USER:$REGISTRY_PASSWORD | base64)"
export CONTEXT_PATH=${INPUT_CONTEXT_PATH}

export DEPLOYMENT_REPO=${INPUT_DEPLOYMENT_REPO}
export DEPLOYMENT_REPO_TOKEN=${INPUT_DEPLOYMENT_REPO_TOKEN}
export EXTRA_ARGS=${INPUT_EXTRA_ARGS}

mkdir -p $HOME/.docker/
#        "insecure-registries" : ["$REGISTRY"],
cat <<EOF >$HOME/.docker/config.json
{
        "auths": {
                "$REGISTRY": {
                        "auth": "$DOCKERHUB_AUTH"
                }
        }
}
EOF

if [ "$IS_OPENFAAS_FN" == "true" ]; then
  FUNCTION_NAME="$(yq eval '.functions | keys' function.yml | awk '{print $2}')"
  echo "Building OpenFAAS Function"
  echo "Function name: $FUNCTION_NAME"
  faas-cli build -f "function.yml" --shrinkwrap || exit 1
  export CONTEXT="./build/$FUNCTION_NAME"
else
  export CONTEXT="$CONTEXT_PATH"
fi

echo "Context: $CONTEXT"

export DOCKERFILE="--file $CONTEXT/${INPUT_DOCKERFILE}"
echo "Dockerfile: $DOCKERFILE"

export DESTINATION="--tag ${REGISTRY}/${IMAGE}:${IMAGE_TAG}"
echo "Destination: $DESTINATION"

export ARGS="--push $DESTINATION $DOCKERFILE $CONTEXT"
echo "Args: $ARGS"

echo "Building image"
buildx build $ARGS || exit 1

export ENVIRONMENT=${INPUT_ENVIRONMENT}
export YAML_FILE_BASE_PATH=/deployment-repo/deployments/$APPLICATION/$ENVIRONMENT

export NEWNAME="${REGISTRY}/${IMAGE}"
export NEWTAG="${IMAGE_TAG}"

git clone https://$DEPLOYMENT_REPO_TOKEN@github.com/$DEPLOYMENT_REPO /deployment-repo || exit 1

if [ "$IS_OPENFAAS_FN" == "true" ]; then
  export IMAGEREPONAMETAG="${NEWNAME}:${NEWTAG}"
  export YAML_FILE="$YAML_FILE_BASE_PATH/image-patch.yaml"
  echo "YAML file: $YAML_FILE"
  yq eval -i '.[0].value = env(IMAGEREPONAMETAG)' "$YAML_FILE" || exit 1
else
  export YAML_FILE="$YAML_FILE_BASE_PATH/${INPUT_YAML_FILE}"
  echo "YAML file: $YAML_FILE"
  yq eval -i '.images[0].name = env(NEWNAME)' "$YAML_FILE" || exit 1  
  yq eval -i '.images[0].newTag = env(NEWTAG)' "$YAML_FILE" || exit 1
  
fi

cd /deployment-repo
git config --local user.email "actions@github.com"
git config --local user.name "GitHub Actions"
git add "${YAML_FILE}"
git commit -m "chore(${APPLICATION}): bumping ${ENVIRONMENT} image tag"
git push
