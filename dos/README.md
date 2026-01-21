# docker build

## 使用

**CentOS**
```shell
make build-el7
```

---

```shell
# 启动容器
# -d: 后台运行
# --privileged: 必须！否则 systemd 无法启动
# -p 2222:22: 将容器的 SSH 22 端口映射到宿主机的 2222 端口
# --name my-vm: 给容器起个名字
docker run -d \
  --privileged \
  --name my-vm \
  -p 2222:22 \
  harbor.einscat.com:10011/library/centos7:aarch64 \
  /usr/sbin/init
```
