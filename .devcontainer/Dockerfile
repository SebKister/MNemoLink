#-------------------------------------------------------------------------------------------------------------
# Flutter Dev Container - Lucas Hilleshein dos Santos.
# Licensed under the MIT License.
# See https://github.com/lucashilles/flutter-dev-container/blob/master/LICENSE for license information.
#-------------------------------------------------------------------------------------------------------------

FROM ubuntu:latest

#Locale
ENV LANG C.UTF-8

# Install needed packages, setup user anda clean up.
RUN cd /tmp \
    && apt-get update \
	&& apt-get install -y \
		clang cmake git \
		wget vim curl \
		ninja-build \
		pkg-config \
		libgtk-3-dev \
		liblzma-dev \
		libstdc++-12-dev \
		sudo zip unzip \
		xz-utils \
	&& apt-get autoremove -y \
	&& apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/*

# Flutter SDK
# https://flutter.dev/docs/development/tools/sdk/releases?tab=linux
ARG FLUTTER_CHANNEL="stable"
# ARG FLUTTER_VERSION="3.3.4"
ENV FLUTTER_VERSION="3.16.5"
# Make sure to use the needed channel and version for this.
ENV FLUTTER_HOME=/flutter
ENV PATH=${PATH}:${FLUTTER_HOME}/bin

# Flutter SDK
RUN mkdir -p ${FLUTTER_HOME} && cd ${FLUTTER_HOME} \
	&& curl -C - \
		--output flutter.tar.xz \
		https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz \
	&& tar -xf flutter.tar.xz --strip-components=1 \
	&& rm flutter.tar.xz

# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
# [Optional] Add sudo support for the non-root user

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN	groupadd --gid ${USER_GID} ${USERNAME} \
	&& useradd -s /bin/bash --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} \
	&& echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
	&& chmod 0440 /etc/sudoers.d/${USERNAME} \
	&& chown ${USERNAME}:${USERNAME} ${FLUTTER_HOME} 

USER ${USER_UID}:${USER_GID}

# Configure Flutter
RUN git config --global --add safe.directory ${FLUTTER_HOME} && \
	flutter --disable-analytics && \
    flutter config --no-cli-animations

WORKDIR /workspace
