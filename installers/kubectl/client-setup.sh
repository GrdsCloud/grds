#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#    http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script should be run after the operator has been deployed
GRDS_OPERATOR_NAMESPACE="${GRDS_OPERATOR_NAMESPACE:-grds}"
GRDS_CLIENT_VERSION="${GRDS_CLIENT_VERSION:-v1.0.0}"
GRDS_CLIENT_URL="https://github.com/GrdsCloud/grds/releases/download/${GRDS_CLIENT_VERSION}"

GRDS_CMD="${GRDS_CMD-kubectl}"

# Checks operating system and determines which binary to download
UNAME_RESULT=$(uname)
if [[ "${UNAME_RESULT}" == "Linux" ]]
then
    BIN_NAME="grds"
elif [[ "${UNAME_RESULT}" == "Darwin" ]]
then
    BIN_NAME="grds-mac"
else
    echo "${UNAME_RESULT} is not supported, valid operating systems are: Linux, Darwin"
    echo "Exiting..."
    exit 1
fi

# Creates the output directory for files
OUTPUT_DIR="${HOME}/.grds/${GRDS_OPERATOR_NAMESPACE}"
install -d -m a-rwx,u+rwx "${OUTPUT_DIR}"

if [ -f "${OUTPUT_DIR}/grds" ]
then
	echo "grds Client Binary detected at: ${OUTPUT_DIR}"
	echo "Updating Binary..."
fi

echo "Operating System found is ${UNAME_RESULT}..."
echo "Downloading ${BIN_NAME} version: ${GRDS_CLIENT_VERSION}..."
curl -Lo "${OUTPUT_DIR}/grds" "${GRDS_CLIENT_URL}/${BIN_NAME}"
chmod +x "${OUTPUT_DIR}/grds"

# Check that the grds.tls secret exists
if [ -z "$($GRDS_CMD get secret -n ${GRDS_OPERATOR_NAMESPACE} grds.tls)" ]
then
    echo "grds.tls Secret not found in namespace: ${GRDS_OPERATOR_NAMESPACE}"
    echo "Please ensure that the MySQL Operator has been installed."
    echo "Exiting..."
    exit 1
fi

# Restrict access to the target file before writing
kubectl_get_private() { touch "$1" && chmod a-rwx,u+rw "$1" && $GRDS_CMD get > "$1" "${@:2}"; }

# Use the grds.tls secret to generate the client cert files
kubectl_get_private "${OUTPUT_DIR}/client.crt" secret -n "${GRDS_OPERATOR_NAMESPACE}" grds.tls -o 'go-template={{ index .data "tls.crt" | base64decode }}'
kubectl_get_private "${OUTPUT_DIR}/client.key" secret -n "${GRDS_OPERATOR_NAMESPACE}" grds.tls -o 'go-template={{ index .data "tls.key" | base64decode }}'

echo "grds client files have been generated, please add the following to your bashrc"
echo "export PATH=${OUTPUT_DIR}:\$PATH"
echo "export GRDS_CA_CERT=${OUTPUT_DIR}/client.crt"
echo "export GRDS_CLIENT_CERT=${OUTPUT_DIR}/client.crt"
echo "export GRDS_CLIENT_KEY=${OUTPUT_DIR}/client.key"
echo "export GRDS_NAMESPACE=${GRDS_OPERATOR_NAMESPACE}"
