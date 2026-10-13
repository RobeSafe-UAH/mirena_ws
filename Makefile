# Docker workflow: the repository is shared with the container at /ros2_ws.
IMAGE         ?= mirena_ws
TAG           ?= jazzy
CONTAINER     ?= mirena_ws
ROS_DOMAIN_ID ?= 42
AUTO_BUILD    ?= 1
CMD           ?= zsh

RUN_FLAGS := \
	--rm -it \
	--name $(CONTAINER) \
	--net host \
	--ipc host \
	--privileged \
	-v /dev:/dev \
	-v "$(CURDIR):/ros2_ws" \
	-e HOST_UID=$(shell id -u) \
	-e HOST_GID=$(shell id -g) \
	-e ROS_DOMAIN_ID=$(ROS_DOMAIN_ID) \
	-e AUTO_BUILD=$(AUTO_BUILD) \
	--runtime nvidia --gpus all \
	-e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,display \
	-e __NV_PRIME_RENDER_OFFLOAD=1 \
	-e __GLX_VENDOR_LIBRARY_NAME=nvidia \
	-e __VK_LAYER_NV_optimus=NVIDIA_only \
	$(if $(DISPLAY),-e DISPLAY=$(DISPLAY) -e QT_X11_NO_MITSHM=1 -v /tmp/.X11-unix:/tmp/.X11-unix)

.DEFAULT_GOAL := help
.PHONY: help build rebuild run attach stop clean

help: ## Show available commands
	@awk -F':.*## ' '/^[a-z-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker image using cached layers
	docker build -t $(IMAGE):$(TAG) docker

rebuild: ## Build a fresh image
	docker build --pull --no-cache -t $(IMAGE):$(TAG) docker

run: ## Start the container and build the workspace (AUTO_BUILD=0 to skip)
	@if [ -n "$(DISPLAY)" ] && command -v xhost > /dev/null; then xhost +SI:localuser:$(shell id -un) > /dev/null; fi
	docker run $(RUN_FLAGS) $(IMAGE):$(TAG) $(CMD)

attach: ## Open another shell in the running container
	docker exec -it -u mirena -e HOME=/home/mirena $(CONTAINER) zsh

stop: ## Stop the running container
	docker stop $(CONTAINER)

clean: ## Remove generated colcon files
	rm -rf build/ install/ log/
