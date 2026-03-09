# openclaw-docker
Your own personal AI assistant. Any OS. Any Platform. The lobster way. 🦞

# run
```bash
# 1. 初始化（首次运行）
# Docker 需要交互式运行来配置 AI 模型和 API 密钥
docker run --rm -it \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw onboard

# 按向导完成：选择模型 → 配置 API 密钥 → 设置聊天通道

# 2. 配置网关模式
docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw config set gateway.mode local

docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw config set gateway.bind lan

docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw config set gateway.trustedProxies '["127.0.0.1", "::1", "10.0.0.0/8"]'

docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw config set gateway.auth.token your_token

# 2026.2.17以上版本需要配置dangerouslyAllowHostHeaderOriginFallback，否则启动失败
docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true

docker run --rm \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
dhso/openclaw:latest \
openclaw doctor --fix

# 3. 启动（守护进程模式，容器会一直运行）
docker run -d \
--name claw \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
--restart=unless-stopped \
dhso/openclaw:latest \
openclaw gateway run

```

# build
```bash
docker build --build-arg OPENCLAW_VERSION=2026.2.17 -t dhso/openclaw:2026.2.17 .
```
