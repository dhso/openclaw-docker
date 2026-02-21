# OpenClaw Docker 镜像
FROM node:22-slim

# 切换 root 用户
USER root

# 设置工作目录
WORKDIR /root

# 设置基础环境变量
ENV HOME=/root
ENV TERM=xterm-256color
ENV NODE_PATH=/usr/local/lib/node_modules
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV NODE_ENV=production

# 安装必要的系统依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    git \
    gosu \
    jq \
    python3 \
    socat \
    tini \
    unzip \
    websockify \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# 更新 npm 到最新版本
RUN npm install -g npm@latest

# 安装 bun
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash
ENV BUN_INSTALL="/usr/local"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# 安装 qmd
RUN bun install -g https://github.com/tobi/qmd

ARG OPENCLAW_VERSION=2026.2.17

# 安装 OpenClaw 和 claude-code
RUN npm install -g openclaw@${OPENCLAW_VERSION} @anthropic-ai/claude-code

# 安装 Playwright 和 Chromium
RUN npm install -g playwright && npx playwright install chromium --with-deps

# 安装 playwright-extra 和 puppeteer-extra-plugin-stealth
RUN npm install -g playwright-extra puppeteer-extra-plugin-stealth

# 安装 bird
RUN npm install -g @steipete/bird

# 创建配置目录并设置权限
RUN mkdir -p /root/.openclaw/workspace

# 安装钉钉插件 - 使用 timeout 防止卡住，忽略错误继续构建
RUN mkdir -p /root/.openclaw/extensions && \
    timeout 300 openclaw plugins install @soimy/dingtalk || true

# 数据持久化目录
VOLUME ["/root/.openclaw"]

# 暴露端口
EXPOSE 18789

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# 默认启动命令
CMD ["openclaw"]