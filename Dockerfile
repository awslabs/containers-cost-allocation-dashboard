# Docker image for Kubecost S3 Exporter
# This image is without shell and package managers, and contains only the app's binary and required libraries

###############
# Build Stage #
###############

# Using Debian image as a source to build the app binary with the required libraries and a specific Python version
FROM python:3.12.1-slim-bookworm AS build

# Fetching binutils which is required for building the Python binary using PyInstaller
RUN set -ex \
    && apt-get update \
    && apt-get -y install binutils \
    && apt-get -y autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/*

# Uninstalling PIP so that it can be later installed as a non-root user
RUN pip3 uninstall -y pip

# Adding a non-root user (named "nonroot")
RUN useradd -u 65532 nonroot -m
USER nonroot
ENV PATH="/home/nonroot/.local/bin:${PATH}"

# Installing and upgrading PIP using the non-root user
RUN python3 -m ensurepip --user
RUN pip3 install --user --upgrade pip==23.3.1

# Installing Kubecost S3 Exporter requirements and PyInstaller
COPY --chown=nonroot:nonroot requirements.txt .
RUN pip3 install -r requirements.txt
RUN pip3 install pyinstaller==6.3.0

# PIP cleanup
RUN pip3 uninstall -y pip

# Creating the binary
## Creating "app" directory and switching to it. This directory is used to host the application files
## Copying the main Python script
## Creating the binary using PyInstaller
WORKDIR /home/nonroot/app
COPY --chown=nonroot:nonroot main.py .
RUN pyinstaller -F main.py --specpath . --hidden-import pyarrow.vendored.version --collect-all dateutil

################################
# Non-Root User Creation Stage #
################################

# In this stage, we create the non-root user and switch to it
# We use a separate stage for this, to not duplicate code, as the user is later referenced in multiple other stages

# Building the image from "scratch" (an empty image), to keep it secure, clean and minimal
FROM scratch AS create_non_root_user

# Copying the users/passwords file from the build stage and switching to the non-root user
COPY --from=build /etc/passwd /etc/passwd
USER nonroot

##############################
# Copy Shared Objects Stages #
##############################

# In the following stages, we copy the Shared Objects per target architecture
# These stages are used as triggers, invoked later by the runtime stage according to the target archtecture
# A separate stage per architecture is required, because the files names are different in each architecture

#                                                  #
# Copy Shared Objects Stage for amd64 Architecture #
#                                                  #

# Starting the Copy Shared Objects stage from the create_non_root_user stage, for amd64 architecture
FROM create_non_root_user AS copy_so_amd64

# Copying Shared Objects which are common to both Python and the app's binary
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libc.so.6 /lib/x86_64-linux-gnu/libc.so.6
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2

# Copying Python's Shared Objects from the build stage, for amd64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /usr/local/bin/../lib/libpython3.12.so.1.0 /usr/local/bin/../lib/libpython3.12.so.1.0
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libm.so.6 /lib/x86_64-linux-gnu/libm.so.6

# Copying the app binary's Shared Objects from the build stage, for amd64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libdl.so.2 /lib/x86_64-linux-gnu/libdl.so.2
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libz.so.1 /lib/x86_64-linux-gnu/libz.so.1
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/x86_64-linux-gnu/libpthread.so.0 /lib/x86_64-linux-gnu/libpthread.so.0

# Copying PyArrow's Shared Objects from the build stage, for amd64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /usr/lib/x86_64-linux-gnu/librt.so.1 /usr/lib/x86_64-linux-gnu/librt.so.1

#                                                  #
# Copy Shared Objects Stage for arm64 Architecture #
#                                                  #

# Starting the Copy Shared Objects stage from the create_non_root_user stage, for arm64 architecture
FROM create_non_root_user AS copy_so_arm64

# Copying Shared Objects which are common to both Python and the app's binary
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/aarch64-linux-gnu/libc.so.6 /lib/aarch64-linux-gnu/libc.so.6
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

# Copying Python's Shared Objects from the build stage, for arm64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /usr/local/bin/../lib/libpython3.12.so.1.0 /usr/local/bin/../lib/libpython3.12.so.1.0
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/aarch64-linux-gnu/libm.so.6 /lib/aarch64-linux-gnu/libm.so.6

# Copying the app binary's Shared Objects from the build stage, for arm64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/aarch64-linux-gnu/libdl.so.2 /lib/aarch64-linux-gnu/libdl.so.2
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/aarch64-linux-gnu/libz.so.1 /lib/aarch64-linux-gnu/libz.so.1
ONBUILD COPY --from=build --chown=nonroot:nonroot /lib/aarch64-linux-gnu/libpthread.so.0 /lib/aarch64-linux-gnu/libpthread.so.0

# Copying PyArrow's Shared Objects from the build stage, for arm64 architecture
ONBUILD COPY --from=build --chown=nonroot:nonroot /usr/lib/aarch64-linux-gnu/librt.so.1 /usr/lib/aarch64-linux-gnu/librt.so.1

#################
# Runtime Stage #
#################

# Here we perform the final actions to prepare the runtime image
# This stage is referencing the target architecture in its "FROM" instructions
# This is so that the relevant target architecture's "Copy Shared Objects" stage will be invoked
# When this is done, the relevant Shared Objects files for the target architecture will be copied

# Setting the target architecture argument
ARG TARGETARCH

# Building the runtime image from the relevant "Copy Shared Objects" stage based on the target architecture
FROM copy_so_$TARGETARCH

# Creating the "/tmp" directory
# Using "WORKDIR" is a trick, because "mkdir" command isn't available in this image
# The "/tmp" directory is required for the app to store temporary files in an ephemeral volume
WORKDIR /tmp

# Copying the main binary
## Creating "app" directory and switching to it. This directory is used to host the application files
## Copying the main binary from the build image
WORKDIR /home/nonroot/app
COPY --from=build --chown=nonroot:nonroot /home/nonroot/app/dist/main .

# Executing the main binary
CMD ["./main"]
