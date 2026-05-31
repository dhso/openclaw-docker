# openclaw-docker
Your own personal AI assistant. Any OS. Any Platform. The lobster way. 🦞

# run
```bash
# 1. 初始化（首次运行）
# Docker 需要交互式运行来配置 AI 模型和 API 密钥
docker run --rm -it \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw onboard

# 按向导完成：选择模型 → 配置 API 密钥 → 设置聊天通道

# 2. 配置网关模式
docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.mode local

docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.bind lan

docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.trustedProxies '["127.0.0.1", "::1", "10.0.0.0/8"]'

docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.auth.token your_token

# 2026.2.17以上版本需要配置dangerouslyAllowHostHeaderOriginFallback，否则启动失败
docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true

docker run --rm \
-e TZ=Asia/Shanghai \
-e SKIP_INSTALL=1 \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
dhso/openclaw:latest \
openclaw doctor --fix

# 3. 启动（守护进程模式，容器会一直运行）
docker run -d \
--name claw \
-e TZ=Asia/Shanghai \
-v openclaw_data:/root/.openclaw \
-v openclaw_cache:/root/.cache \
--restart=unless-stopped \
-p 18789:18789 \
dhso/openclaw:latest \
openclaw gateway run

# 4. 访问 http://ip:18789

```


# build
```bash
docker build --build-arg OPENCLAW_VERSION=2026.2.17 -t dhso/openclaw:2026.2.17 .
```

# extra dependencies

镜像 build 阶段仍预装基础依赖；如需追加依赖，可以把清单放在 `/root/.openclaw` 下，容器启动时会自动安装：

- `/root/.openclaw/apt.txt`: 额外 apt 包，每行一个
- `/root/.openclaw/uv.txt`: 额外 Python 依赖，安装到 `${OPENCLAW_PYTHON_VENV_DIR:-/opt/openclaw-python}` 虚拟环境
- `/root/.openclaw/npm.txt`: 额外全局 npm 依赖，支持 `openclaw@${OPENCLAW_VERSION}`
- `/root/.openclaw/bun.txt`: 额外全局 Bun 依赖，支持 `openclaw@${OPENCLAW_VERSION}`
- `/root/.openclaw/openclaw-plugins.txt`: 额外 OpenClaw 插件

镜像会把仓库中的 `apt.txt`、`uv.txt`、`npm.txt`、`bun.txt`、`openclaw-plugins.txt` 作为默认清单复制到 `/usr/local/share/openclaw-docker/defaults/`，容器启动时会把 `/root/.openclaw/` 下缺失或 0 字节的清单初始化为默认内容。安装时会合并默认清单和 `/root/.openclaw/` 下的用户清单，并按行去重。默认 `apt.txt` 包含 `socat`、`websockify`；`uv.txt` 中的 Python 依赖会安装到专用虚拟环境并通过 `PATH` 优先使用；`chromium` 已在 build 阶段预装。

建议挂载 `openclaw_cache:/root/.cache`，用于持久化 apt、uv、pip、npm、Bun 和 Playwright 缓存。新容器仍会检查并安装 `/root/.openclaw` 中的额外依赖，但会复用缓存加速下载。

初始化、配置或 doctor 这类一次性命令可以设置 `-e SKIP_INSTALL=1` 跳过启动时的额外依赖安装；正式运行 `openclaw gateway run` 时不设置该变量即可自动检查并安装清单中的额外依赖。也可以使用等价变量 `OPENCLAW_SKIP_INSTALL=1`。
