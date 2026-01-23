#!/bin/bash

# 检查必需的依赖工具
check_dependencies() {
  local missing_deps=()

  # 检查 jq
  if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
  fi

  # 检查 yq
  if ! command -v yq &> /dev/null; then
    missing_deps+=("yq")
  fi

  # 检查 docker
  if ! command -v docker &> /dev/null; then
    missing_deps+=("docker")
  fi

  # 如果有缺失的依赖，输出错误信息并退出
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing required dependencies: ${missing_deps[*]}"
    echo ""
    echo "Please install the missing tools:"
    for dep in "${missing_deps[@]}"; do
      case $dep in
        jq)
          echo "  - jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
          ;;
        yq)
          echo "  - yq: brew install yq (macOS) or snap install yq (Ubuntu)"
          ;;
        docker)
          echo "  - docker: https://docs.docker.com/get-docker/"
          ;;
      esac
    done
    exit 1
  fi
}

# 检查必需的配置文件
check_required_files() {
  local missing_files=()

  if [ ! -f ".env" ]; then
    missing_files+=(".env")
  fi

  if [ ! -f "${CONFIG_FILE}" ]; then
    missing_files+=("${CONFIG_FILE}")
  fi

  if [ ! -f "${TEMPLATES_FILE}" ]; then
    missing_files+=("${TEMPLATES_FILE}")
  fi

  if [ ${#missing_files[@]} -gt 0 ]; then
    echo "Error: Missing required configuration files: ${missing_files[*]}"
    echo "Please ensure all configuration files exist in the current directory."
    exit 1
  fi
}

# 执行依赖检查
check_dependencies

# 加载环境变量，用于后续的 Docker 配置
source .env

# 定义脚本中使用的 JSON 配置文件、输出的 Docker Compose 配置文件和模板文件的路径。
CONFIG_FILE=./config.json
COMPOSE_FILE=./docker-compose.yaml
TEMPLATES_FILE=./templates.yaml

# 检查必需的配置文件是否存在
check_required_files

# 检查 HOST_NUMBER 是否在 5 到 253 之间，确保分配的 IP 地址范围合理，超出范围脚本会退出。
#if [[ ${HOST_NUMBER} -gt 253 || ${HOST_NUMBER} -lt 5 ]]; then
#    echo "HOST_NUMBER must be between 5 and 253"
#    exit 1
#fi

# Docker Compose 初始化
# 脚本最初在 ${COMPOSE_FILE} 中创建或覆盖以 version: '3' 和 x-templates: 开头的内容。
cat > ${COMPOSE_FILE} <<EOF
x-templates:
EOF

# 将输入的字符串转换为小写
# Function to convert key to lowercase
to_lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# 检查一个元素是否存在于数组中。
# Check if an element is in an array
# "$1" 是要检查的元素，${@:2} 表示其后所有参数（即数组的元素）
# “$1” 代表调用函数时传递的第一个参数
# “${@:2}” 代表所有传递给函数的参数，从第二个参数开始的所有参数，
# 2 是一个索引，表示从第二个参数开始（记得在 Bash 中，参数索引从 1 开始，而非 0）。所以，这指的是在函数调用时，除了第一个参数之外的所有参数。
contains_element() {
  local element
  for element in "${@:2}"; do
    if [[ "$element" == "$1" ]]; then
      return 0
    fi
  done
  return 1
}

# --- [新增优化] 自动计算并检查容器总数 ---
# 使用 jq 筛选出所有 enabled=true 的项，提取 count 并相加
TOTAL_VMS=$(jq '[to_entries[] | select(.value.enable == true) | .value.count] | add' ${CONFIG_FILE})

echo "Plan to deploy ${TOTAL_VMS} containers..."

# 检查实际数量是否导致 IP 溢出 (子网掩码 /24 最多支持约 253 个主机)
if [[ "${TOTAL_VMS}" -gt 253 ]]; then
    echo "Error: Total container count (${TOTAL_VMS}) exceeds the subnet limit of 253."
    echo "Please reduce the 'count' in config.json or disable some groups."
    exit 1
fi

if [[ "${TOTAL_VMS}" -lt 1 ]]; then
    echo "Error: No containers enabled. Please enable at least one group in config.json."
    exit 1
fi
# -------------------------------------

# 初始化一个空数组
# Initialize an array to track added templates
templates=()

# 读取 config.json 文件中的每个条目，检查是否启用（enable 字段为 true）。
# 找到启用的模板后，将其添加到 docker-compose.yaml 的 x-templates 部分，如果未添加过则进行处理。
# 使用 yq 命令从模板文件中提取模板内容加入构建的 docker-compose.yaml。
# jq 学习链接：https://jqlang.org/tutorial/
# `to_entries` 是 jq 中一个内置函数，用于将JSON对象转换为一个键值对数组
# 首先使用内置函数将对象转换为数组，然后通过进程替换传递到 while 循环中，一次读取一个键值对，存储在 entry 变量中。
# 使用进程替换 < <(...) 而不是管道，避免子shell导致的变量作用域问题
while read -r entry; do
  # 使用 jq -r 从 entry 中提取 key 值，-r 表示以原始格式输出，不加引号。
  key=$(echo "${entry}" | jq -r '.key')
  value=$(echo "${entry}" | jq -r '.value')
  enable=$(echo "${value}" | jq -r '.enable')
  template="agent_$(to_lowercase ${key})"

  if [[ "${enable}" == "true" ]]; then
    # Add template to the file if not already added
    if ! contains_element "${template}" "${templates[@]}"; then
      echo "  ${template}:" >> ${COMPOSE_FILE}
      # 如果模板尚未添加，则将模板名称写入 COMPOSE_FILE，格式为 agent_x:。
      # 使用 yq 从指定的模板文件中提取该模板的内容，并通过 sed 将每行前加四个空格（以符合 YAML 格式的缩进），然后追加到 COMPOSE_FILE。
      yq eval ".x-templates.${template}" ${TEMPLATES_FILE} | sed 's/^/    /' >> ${COMPOSE_FILE}
      # 已添加的模板名称添加到 templates 数组中，避免重复添加
      templates+=("${template}")
    fi
  fi
done < <(jq -c 'to_entries[]' ${CONFIG_FILE})

# 向 docker-compose.yaml 添加 services: 部分，准备为每个服务定义详细信息
echo "
services:" >> ${COMPOSE_FILE}

#读取 config.json 中启用的服务配置，获取每个条目对应的服务信息。
#服务信息包含：容器名称、主机名、网络配置及其特定 IP 地址、可能的端口映射和卷挂载。
#根据服务次数（count），为每个配置生成相应数量的服务实例。
#特定条件下（例如，特定架构），加入平台声明。
container_index=1
# Process JSON file
# 使用进程替换 < <(...) 而不是管道，避免子shell导致 container_index 无法递增
while read -r entry; do
  key=$(echo "${entry}" | jq -r '.key')
  value=$(echo "${entry}" | jq -r '.value')

  enable=$(echo "${value}" | jq -r '.enable')
  count=$(echo "${value}" | jq -r '.count')

  volumes=$(echo "${value}" | jq -r '.volumes[]')

  ## mac 不支持该语法
  ## template="agent_${key,,}"
  template="agent_$(to_lowercase ${key})"

  # Only process enabled configurations
  if [[ "${enable}" == "true" ]]; then
    for ((i=1; i<=count; i++)); do
      echo "
  vm-${container_index}:
    container_name: vm-${container_index}
    hostname: \"vm-${container_index}\"
    privileged: true
    networks:
      vm_net:
        ipv4_address: 172.20.30.${container_index}
      vm_net_2:
        ipv4_address: 172.20.40.${container_index}" >> ${COMPOSE_FILE}

      # 检查并处理端口映射
      ports=$(echo "${value}" | jq -r --arg idx "vm-${container_index}" '.ports[$idx] // [] | .[]')
      if [[ -n "${ports}" ]]; then
        echo "    ports:" >> ${COMPOSE_FILE}
        for port in ${ports}; do
          echo "      - \"${port}\"" >> ${COMPOSE_FILE}
        done
      fi

      ## 检查并处理卷映射
      if [[ -n "${volumes}" ]]; then
        echo "    volumes:" >> ${COMPOSE_FILE}
        for volume in ${volumes}; do
          echo "      - \"${volume}\"" >> ${COMPOSE_FILE}
        done
      fi

      echo "    <<: *${template}" >> ${COMPOSE_FILE}
      ((container_index++))
    done
  fi
done < <(jq -c 'to_entries[]' ${CONFIG_FILE})

# 定义两个网络 vm_net 和 vm_net_2，每个网络分配不同的子网和网关
echo "
networks:
  vm_net:
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.20.30.0/24
          gateway: 172.20.30.254
  vm_net_2:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.40.0/24
          gateway: 172.20.40.254
" >> ${COMPOSE_FILE}

# 输出生成成功的提示信息
echo "docker-compose.yaml has been generated successfully."
