ARG TALOS_BASE_IMAGE="talosacr.azurecr.io/talos:latest"
FROM ${TALOS_BASE_IMAGE}

COPY scripts scripts/
