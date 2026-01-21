# ==============================================================================
# 统一构建管理 (CentOS / Rocky / Ubuntu)
# 架构规范遵循:
# CentOS/RHEL: x86_64 / aarch64
# Ubuntu:      amd64  / arm64
# Docker:      linux/amd64 / linux/arm64
# ==============================================================================

REGISTRY := finnley
ROOT_PASSWORD ?= sshpass
TIMEZONE ?= Asia/Shanghai

# --- 1. 宿主机检测 ---
HOST_ARCH := $(shell uname -m)

# --- 2. 归一化为 Docker 标准 (amd64 / arm64) ---
ifeq ($(HOST_ARCH), aarch64)
    DEFAULT_ARCH := arm64
else ifeq ($(HOST_ARCH), arm64)
    DEFAULT_ARCH := arm64
else
    DEFAULT_ARCH := amd64
endif

# 允许命令行传参覆盖 (例如: make build-el7 ARCH=amd64)
ARCH ?= $(DEFAULT_ARCH)

# --- 3. 映射为各发行版官方名称 ---
DOCKER_PLATFORM := linux/$(ARCH)

ifeq ($(ARCH), arm64)
    RHEL_ARCH   := aarch64
    UBUNTU_ARCH := arm64
else
    RHEL_ARCH   := x86_64
    UBUNTU_ARCH := amd64
endif

.PHONY: help clean-playground build-el7 build-rocky8 build-el8 build-ubuntu
.PHONY: playground-el7 playground-rocky8 playground-ubuntu enter
.PHONY: push-el7 push-rocky8 push-ubuntu

default: help

# ==============================================================================
# 帮助信息 (Help) - 已完全汉化补全
# ==============================================================================
help:
	@echo "======================================================================"
	@echo "                     容器镜像构建控制台 (QuickUsage)"
	@echo "======================================================================"
	@echo " [当前环境状态]"
	@echo "   宿主机架构      : $(HOST_ARCH)"
	@echo "   目标架构 (ARCH) : $(ARCH)  (Docker标准: $(DOCKER_PLATFORM))"
	@echo "   RHEL系标签      : $(RHEL_ARCH)"
	@echo "   Ubuntu系标签    : $(UBUNTU_ARCH)"
	@echo ""
	@echo " [1. 生产构建指令]"
	@echo "   make build-el7         -> 构建 CentOS 7 镜像"
	@echo "   make build-el8         -> 构建 CentOS 8 镜像"
	@echo "   make build-rocky8      -> 构建 Rocky Linux 8 镜像"
	@echo "   make build-ubuntu      -> 构建 Ubuntu 20.04 镜像"
	@echo ""
	@echo " [2. 沙盒调试指令 (Playground)]"
	@echo "   make playground-el7    -> 启动 CentOS 7 测试容器 (后台运行)"
	@echo "   make playground-rocky8 -> 启动 Rocky 8 测试容器 (后台运行)"
	@echo "   make playground-ubuntu -> 启动 Ubuntu 测试容器 (后台运行)"
	@echo "   make enter             -> 进入当前正在运行的测试容器"
	@echo "   make clean-playground  -> 停止并删除所有测试容器"
	@echo ""
	@echo " [3. 镜像推送指令 (Push)]"
	@echo "   make push-el7          -> 推送 CentOS 7 到仓库 $(REGISTRY)"
	@echo "   make push-rocky8       -> 推送 Rocky 8 到仓库 $(REGISTRY)"
	@echo "   make push-ubuntu       -> 推送 Ubuntu 到仓库 $(REGISTRY)"
	@echo ""
	@echo " [高级用法示例]"
	@echo "   # 在 M1/M2 Mac (arm64) 上强制构建 x86 镜像:"
	@echo "   make build-el7 ARCH=amd64"
	@echo "======================================================================"

# ==========================================
# 1. 生产构建
# ==========================================

build-el7:
	docker build --platform $(DOCKER_PLATFORM) \
		--build-arg BASE_IMAGE=centos:centos7.9.2009 \
		--build-arg DISTRO=centos \
		--build-arg OS_VERSION=7 \
		--build-arg ARCH=$(RHEL_ARCH) \
		--build-arg ROOT_PASSWORD=$(ROOT_PASSWORD) \
		-f Dockerfile.rhel \
		-t $(REGISTRY)/centos7:$(RHEL_ARCH) .

build-rocky8:
	docker build --platform $(DOCKER_PLATFORM) \
		--build-arg BASE_IMAGE=rockylinux:8 \
		--build-arg DISTRO=rocky \
		--build-arg OS_VERSION=8 \
		--build-arg ARCH=$(RHEL_ARCH) \
		--build-arg ROOT_PASSWORD=$(ROOT_PASSWORD) \
		-f Dockerfile.rhel \
		-t $(REGISTRY)/rockylinux8:$(RHEL_ARCH) .

build-el8:
	docker build --platform $(DOCKER_PLATFORM) \
		--build-arg BASE_IMAGE=centos:centos8.4.2105 \
		--build-arg DISTRO=centos \
		--build-arg OS_VERSION=8 \
		--build-arg ARCH=$(RHEL_ARCH) \
		--build-arg ROOT_PASSWORD=$(ROOT_PASSWORD) \
		-f Dockerfile.rhel \
		-t $(REGISTRY)/centos8:$(RHEL_ARCH) .

build-ubuntu:
	docker build --platform $(DOCKER_PLATFORM) \
		--build-arg BASE_IMAGE=ubuntu:focal \
		--build-arg ARCH=$(UBUNTU_ARCH) \
		--build-arg ROOT_PASSWORD=$(ROOT_PASSWORD) \
		-f Dockerfile.ubuntu \
		-t $(REGISTRY)/ubuntu2004:$(UBUNTU_ARCH) .

# ==========================================
# 2. 沙盒调试
# ==========================================
clean-playground:
	@docker rm -f playground-el7 playground-rocky8 playground-ubuntu 2>/dev/null || true
	@echo ">>> [系统] 已清理所有沙盒容器"

playground-el7: clean-playground
	@echo ">>> [启动] CentOS 7 沙盒 ($(RHEL_ARCH))..."
	@docker build -q --platform $(DOCKER_PLATFORM) -f Dockerfile.test -t test-env:el7 \
		--build-arg BASE_IMAGE=centos:centos7.9.2009 \
		--build-arg DISTRO=centos \
		--build-arg OS_VERSION=7 \
		--build-arg ARCH=$(RHEL_ARCH) .
	@docker run -d --privileged --platform $(DOCKER_PLATFORM) --name playground-el7 \
		-v $(PWD):/workspace test-env:el7 /usr/sbin/init
	@docker exec -it playground-el7 /bin/bash

playground-rocky8: clean-playground
	@echo ">>> [启动] Rocky 8 沙盒 ($(RHEL_ARCH))..."
	@docker build -q --platform $(DOCKER_PLATFORM) -f Dockerfile.test -t test-env:rocky8 \
		--build-arg BASE_IMAGE=rockylinux:8 \
		--build-arg DISTRO=rocky \
		--build-arg OS_VERSION=8 \
		--build-arg ARCH=$(RHEL_ARCH) .
	@docker run -d --privileged --platform $(DOCKER_PLATFORM) --name playground-rocky8 \
		-v $(PWD):/workspace test-env:rocky8 /usr/sbin/init
	@docker exec -it playground-rocky8 /bin/bash

playground-ubuntu: clean-playground
	@echo ">>> [启动] Ubuntu 沙盒 ($(UBUNTU_ARCH))..."
	@docker build -q --platform $(DOCKER_PLATFORM) -f Dockerfile.test -t test-env:ubuntu \
		--build-arg BASE_IMAGE=ubuntu:focal \
		--build-arg ARCH=$(UBUNTU_ARCH) .
	@docker run -d --privileged --platform $(DOCKER_PLATFORM) --name playground-ubuntu \
		-v $(PWD):/workspace test-env:ubuntu /sbin/init
	@docker exec -it playground-ubuntu /bin/bash

enter:
	@if docker ps | grep -q playground-rocky8; then echo ">>> 进入 Rocky 8 容器..."; docker exec -it playground-rocky8 /bin/bash; \
	elif docker ps | grep -q playground-el7; then echo ">>> 进入 CentOS 7 容器..."; docker exec -it playground-el7 /bin/bash; \
	elif docker ps | grep -q playground-ubuntu; then echo ">>> 进入 Ubuntu 容器..."; docker exec -it playground-ubuntu /bin/bash; \
	else echo "!!! 未发现运行中的沙盒容器，请先运行 make playground-xxx"; fi

# ==========================================
# 3. 推送
# ==========================================
push-el7:
	docker push $(REGISTRY)/centos7:$(RHEL_ARCH)

push-rocky8:
	docker push $(REGISTRY)/rockylinux8:$(RHEL_ARCH)

push-ubuntu:
	docker push $(REGISTRY)/ubuntu2004:$(UBUNTU_ARCH)