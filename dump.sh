#!/bin/bash

if [ -f _env ]; then
    source _env
fi


# Validate the input variables
if [[ -z "$NAMESPACE" ]]; then
    echo "Error: variable NAMESPACE is invalid or not defined"
    exit 1
fi
namespace="$NAMESPACE"

IFS=',' read -ra crl_urls <<< "$CRL_URLS"
if [[ -z "$CRL_URLS" ]] || [[ ${#crl_urls[@]} -eq 0 ]]; then
    echo "Error: variable CRL_URLS is invalid of not defined"
    exit 1
fi

output_file="ca.crl"
current_timestamp=$(date +"%Y%m%d%H%M%S")
output_file="${output_file%.*}_$current_timestamp.${output_file##*.}"
temp_crl="temp.crl"

# For each .pem file in the current directory
for crl_url in "${crl_urls[@]}"; do
    # If a CRL URL was found
    if [ ! -z "$crl_url" ]; then
        # Download the CRL to a temporary file
        echo "Downloading $crl_url"
        curl -s "$crl_url" -o "$temp_crl"

        # If the download was successful, append to the output file
        if [ $? -eq 0 ]; then
            #convert to pem
            openssl crl -inform DER -in "$temp_crl" -outform PEM -out "$temp_crl"
            cat "$temp_crl" >> "$output_file"
        else
            echo "Error: Failed to download CRL for $pem from $crl_url"
            exit 1
        fi
    else
        echo "Error: No CRL URL found in $pem"
        exit 1
    fi
done

# Clean up the temporary file
rm -f "$temp_crl"

echo "Done! All CRLs appended to $output_file."

echo "Get current secret $namespace/ca"
kubectl get secret ca -n "$namespace" -o yaml > current_ca.yaml
if [ $? -ne 0 ]; then
    echo "Error: Failed to get current secret $namespace/ca"
    exit 1
fi

export NEW_ENCODED_VALUE
NEW_ENCODED_VALUE=$(base64 < "$output_file" | tr -d '\n')
if [ -z "$NEW_ENCODED_VALUE" ]; then
    echo "Error: Failed to encode $output_file"
    exit 1
fi

cp current_ca.yaml new_ca.yaml
echo "Replace secret with new ca.crl"
yq eval '.data."ca.crl" = env(NEW_ENCODED_VALUE)' new_ca.yaml -i
if [ $? -ne 0 ]; then
    echo "Error: Failed to replace secret $namespace/ca"
    exit 1
fi

kubectl apply -f new_ca.yaml
if [ $? -ne 0 ]; then
    echo "Error: Failed to replace secret $namespace/ca"
    exit 1
fi

REPLACED_VALUE=$(kubectl get secret ca -n $NAMESPACE -o=jsonpath='{.data.ca\.crl}')
if [ $? -ne 0 ]; then
    echo "Error: Failed to get new value. Unable to verify if the secret was replaced".
    exit 1
fi

if [[ "$REPLACED_VALUE" == "$NEW_ENCODED_VALUE" ]]; then
    echo "New secret successfully replaced."
else
    echo "Error: New secret was not replaced."
    exit 1
fi

openssl crl -noout -in "$output_file" -nextupdate
