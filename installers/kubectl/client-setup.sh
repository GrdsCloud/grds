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
SQUIDS_OPERATOR_NAMESPACE="${SQUIDS_OPERATOR_NAMESPACE:-squids}"
SQUIDS_CLIENT_VERSION="${SQUIDS_CLIENT_VERSION:-v1.0.0}"
SQUIDS_CLIENT_URL="https://github.com/squids-io/grds/releases/download/${SQUIDS_CLIENT_VERSION}"

SQUIDS_CMD="${SQUIDS_CMD-kubectl}"

# Checks operating system and determines which binary to download
UNAME_RESULT=$(uname)
if [[ "${UNAME_RESULT}" == "Linux" ]]
then
    BIN_NAME="squidsctl"
elif [[ "${UNAME_RESULT}" == "Darwin" ]]
then
    BIN_NAME="squidsctl-mac"
else
    echo "${UNAME_RESULT} is not supported, valid operating systems are: Linux, Darwin"
    echo "Exiting..."
    exit 1
fi

# Creates the output directory for files
OUTPUT_DIR="${HOME}/.squids"
install -d -m a-rwx,u+rwx "${OUTPUT_DIR}"

if [ -f "${OUTPUT_DIR}/squidsctl" ]
then
	echo "squids Client Binary detected at: ${OUTPUT_DIR}"
	echo "Updating Binary..."
fi

echo "Operating System found is ${UNAME_RESULT}..."
echo "Downloading ${BIN_NAME} version: ${SQUIDS_CLIENT_VERSION}..."
curl -Lo "${OUTPUT_DIR}/squidsctl" "${SQUIDS_CLIENT_URL}/${BIN_NAME}"
chmod +x "${OUTPUT_DIR}/squidsctl"

# Check that the squids.tls secret exists
if [ -z "$($SQUIDS_CMD get secret -n ${SQUIDS_OPERATOR_NAMESPACE} squids.tls)" ]
then
    echo "squids.tls Secret not found in namespace: ${SQUIDS_OPERATOR_NAMESPACE}"
    echo "Please ensure that the MySQL Operator has been installed."
    echo "Exiting..."
    exit 1
fi

# Restrict access to the target file before writing
kubectl_get_private() { touch "$1" && chmod a-rwx,u+rw "$1" && $SQUIDS_CMD get > "$1" "${@:2}"; }

# Use the squids.tls secret to generate the client cert files
kubectl_get_private "${OUTPUT_DIR}/client.crt" secret -n "${SQUIDS_OPERATOR_NAMESPACE}" squids.tls -o 'go-template={{ index .data "tls.crt" | base64decode }}'
kubectl_get_private "${OUTPUT_DIR}/client.key" secret -n "${SQUIDS_OPERATOR_NAMESPACE}" squids.tls -o 'go-template={{ index .data "tls.key" | base64decode }}'

echo "squids client files have been generated, please add the following to your bashrc"
echo "export PATH=${OUTPUT_DIR}:\$PATH"
echo "export SQUIDS_CA_CERT=${OUTPUT_DIR}/client.crt"
echo "export SQUIDS_CLIENT_CERT=${OUTPUT_DIR}/client.crt"
echo "export SQUIDS_CLIENT_KEY=${OUTPUT_DIR}/client.key"
echo "export SQUIDS_NAMESPACE=${SQUIDS_OPERATOR_NAMESPACE}"
