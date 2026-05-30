# OpenClaw Docker 镜像
FROM node:24-slim

# 切换 root 用户
USER root

# 设置工作目录
WORKDIR /root

# 设置基础环境变量
ENV HOME=/root
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TERM=xterm-256color
ENV NODE_PATH=/usr/local/lib/node_modules
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV NODE_ENV=production
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_CACHE_DIR=/root/.cache/pip
ENV UV_CACHE_DIR=/root/.cache/uv
ENV npm_config_cache=/root/.cache/npm
ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
ENV BUN_INSTALL=/root/.bun
ENV BUN_INSTALL_CACHE_DIR=/root/.cache/bun/install
ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=/root/.cache/bun/transpiler
ENV PATH="/root/.local/bin:/root/.bun/bin:${PATH}"
ARG OPENCLAW_VERSION=2026.2.17
ENV OPENCLAW_VERSION=${OPENCLAW_VERSION}

# 安装必要的系统依赖
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    chromium \
    curl \
    fontconfig \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-color-emoji \
    fonts-wqy-zenhei \
    git \
    gosu \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    tini \
    unzip \
  && fc-cache -fv \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/*

# 安装 uv (Python 包管理器)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# 安装 Bun
RUN curl -fsSL https://bun.com/install | bash

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY apt.txt requirement.txt npm.txt bun.txt openclaw-plugins.txt /root/.openclaw/

# 更新 npm 到最新版本
# RUN npm install -g npm@latest

# 安装 qmd
RUN npm install -g @tobilu/qmd

# 安装 playwright 以及插件
RUN npm install -g playwright playwright-extra puppeteer-extra-plugin-stealth \
  && npx playwright install chromium --with-deps

# 安装 OpenClaw
RUN npm install -g openclaw@${OPENCLAW_VERSION} clawhub

# 创建配置目录并设置权限
RUN mkdir -p /root/.openclaw/workspace /root/.openclaw/extensions /root/.cache \
  && chmod +x /usr/local/bin/docker-entrypoint.sh

# 安装 OpenClaw 插件 - 使用 timeout 防止卡住，忽略错误继续构建
RUN timeout 300 openclaw plugins install @soimy/dingtalk || true

# 数据持久化目录
VOLUME ["/root/.openclaw", "/root/.cache"]

# 暴露端口
EXPOSE 18789

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# 默认启动命令
ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["openclaw"]
