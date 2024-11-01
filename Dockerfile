ARG TALOS_VERSION="latest"
FROM talossandbox.azurecr.io/talos:${TALOS_VERSION}

COPY scripts scripts/
