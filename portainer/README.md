# Portainer 自动 API Key 配置

这个自定义 Portainer 配置会在容器启动时自动创建 API Key 并更新到主项目的 `.env` 文件中。

## 文件说明

- `Dockerfile`: 基于官方 Portainer 镜像的自定义构建
- `portainer-init.sh`: 合并的启动和 API Key 初始化脚本

## 工作流程

1. **容器启动**: 使用自定义 Dockerfile 构建 Portainer 镜像
2. **Portainer 启动**: 在后台启动 Portainer 服务
3. **等待就绪**: 等待 30 秒确保 Portainer 完全启动
4. **自动认证**: 使用管理员账户进行 API 认证
5. **创建 API Key**: 自动创建名为 "Homepage Dashboard API Key" 的 token
6. **保存到文件**: 将 API Key 保存到容器内的 `/data/api_key.txt`
7. **更新环境变量**: 自动更新主机的 `.env` 文件中的 `PORTAINER_API_KEY`

## 使用方法

### 1. 构建和启动
```bash
# 构建自定义 Portainer 镜像并启动
docker-compose up -d portainer

# 查看初始化日志
docker-compose logs -f portainer
```

### 2. 验证 API Key
```bash
# 检查 API Key 是否已创建
docker-compose exec portainer cat /data/api_key.txt

# 检查 .env 文件是否已更新
grep PORTAINER_API_KEY .env
```

### 3. 重启 Homepage 服务
API Key 创建后，重启 Homepage 服务以加载新的环境变量：
```bash
docker-compose restart homepage
```

## 环境变量

- `PORTAINER_INITIAL_ADMIN_PASSWORD`: Portainer 管理员密码
- `ENV_FILE_PATH`: 主机 .env 文件在容器内的路径（默认: `/host-env/.env`）

## 注意事项

1. **首次启动**: 确保 `PORTAINER_INITIAL_ADMIN_PASSWORD` 已在 `.env` 文件中设置
2. **权限问题**: 脚本会自动处理文件权限
3. **重复运行**: 如果 API Key 已存在，脚本会跳过创建过程
4. **日志监控**: 可以通过 `docker-compose logs portainer` 查看初始化过程

## 故障排除

### API Key 创建失败
- 检查管理员密码是否正确
- 确认 Portainer 服务已完全启动
- 查看容器日志获取详细错误信息

### 环境变量未更新
- 检查 `.env` 文件的挂载路径
- 确认容器有写入权限
- 验证 `ENV_FILE_PATH` 环境变量设置

### Homepage 无法连接 Portainer
- 确认 API Key 已正确设置
- 检查网络连接和端口配置
- 验证 Portainer API 端点可访问性