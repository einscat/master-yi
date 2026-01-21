PWD = $(shell pwd)
TARGET_DOCKER_TMP_DIR = "/tmp/deploy"
TARGET_DOCKER = "chaos-1"

default: docker_up

deploy:
	make up
#	docker exec ${TARGET_DOCKER} rm -rf ${TARGET_DOCKER_TMP_DIR}
#	docker cp ${PWD} ${TARGET_DOCKER}:${TARGET_DOCKER_TMP_DIR}
	#docker exec -t ${TARGET_DOCKER} chmod +x ${TARGET_DOCKER_TMP_DIR}/udp_install.sh
	#docker exec -t ${TARGET_DOCKER} ${TARGET_DOCKER_TMP_DIR}/udp_install.sh

prepare:
	./setup.sh

up:
	docker compose up -d

clean:
	docker compose down --remove-orphans
