```md
# Conventions

## Directory Layout

- 每个应用一个目录：`stacks/<app-name>/`
- 必须包含：
  - `docker-compose.yml`
  - `README.md`
  - `.env.example`

## Compose Rules

- 使用 `restart: unless-stopped`
- 优先使用相对路径挂载：`./data:/...`
- 不提交 `.env`，敏感值全部通过环境变量注入
- 端口暴露遵循最小化原则：能不暴露就不暴露

## Naming

- 目录名：小写 + 连字符（kebab-case），例如：`nginx-proxy-manager`
- container_name：可读、稳定，和目录一致或近似