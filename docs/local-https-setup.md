# 本地 HTTPS 配置说明

本文档说明如何在本地开发环境中配置和使用 HTTPS。

## 配置概览

当前配置已经为本地 HTTPS 做好了准备：

### 1. 主要配置

- **HTTPS 入口点**: `websecure` (端口 443)
- **HTTP 重定向**: 所有 HTTP 请求自动重定向到 HTTPS
- **自签名证书**: Traefik 自动生成和管理
- **支持的域名**: 
  - `localhost` / `www.localhost`
  - `traefik.localhost`
  - `search.localhost`
  - `portainer.localhost`
  - `logs.localhost`
  - `minio.localhost`
  - `error.localhost`
  - `registry.localhost`
  - `watchtower.localhost`

### 2. 启动服务

```bash
# 在项目根目录执行
docker-compose up -d
```

### 3. 访问 HTTPS 服务

启动后，可以通过以下 URL 访问服务：

- **主应用**: https://localhost
- **Traefik Dashboard**: https://traefik.localhost
- **搜索服务**: https://search.localhost
- **日志查看器**: https://logs.localhost
- **对象存储**: https://minio.localhost
- **错误页面**: https://error.localhost

## 浏览器安全警告处理

由于使用自签名证书，浏览器会显示安全警告。以下是处理方法：

### Chrome/Edge

1. 访问 `https://localhost`
2. 点击 "高级" → "继续前往 localhost (不安全)"
3. 或者添加证书例外

### Firefox

1. 访问 `https://localhost`
2. 点击 "高级" → "接受风险并继续"
3. 或者添加安全例外

### Safari

1. 访问 `https://localhost`
2. 点击 "显示详细信息" → "访问此网站"
3. 或者信任证书

## 高级配置选项

### 1. 使用自定义证书（可选）

如果需要使用自定义证书，可以运行证书生成脚本：

```bash
# 生成证书
./traefik/certs/generate-certs.sh --generate

# 生成并安装到系统（推荐）
./traefik/certs/generate-certs.sh --install
```

然后更新 Traefik 配置使用自定义证书。

### 2. 禁用 HTTPS（开发时）

如果需要临时禁用 HTTPS，可以：

1. 注释掉 `web` 入口点的重定向配置
2. 将路由的 `entryPoints` 改回 `web`
3. 重启 Traefik 服务

### 3. 添加新域名

在 `traefik/config/dynamic.yml` 中添加新的路由：

```yaml
http:
  routers:
    your-service:
      entryPoints:
        - "websecure"
      rule: "Host(`your-service.localhost`)"
      service: "your-service"
      tls: {}
```

## 故障排除

### 1. 证书错误

如果遇到证书错误：

- 确保浏览器信任自签名证书
- 检查 Traefik 日志：`docker logs traefik`
- 验证端口 443 未被占用

### 2. 服务无法访问

- 检查所有服务是否正常启动：`docker-compose ps`
- 验证网络配置：`docker network ls`
- 检查防火墙设置

### 3. 重定向循环

- 检查 `web` 入口点的重定向配置
- 验证服务是否在正确的端口监听

## 生产环境注意事项

当前配置仅适用于开发环境。生产环境需要：

1. 使用 Let's Encrypt 或其他 CA 的证书
2. 配置真实的域名
3. 启用更强的安全设置
4. 配置适当的监控和日志

## 相关文件

- `traefik/traefik.yml` - Traefik 主配置文件
- `traefik/config/dynamic.yml` - 动态路由配置
- `traefik/certs/generate-certs.sh` - 证书生成脚本
- `docker-compose.yml` - Docker 服务配置

## 技术支持

如有问题，请检查：
1. Traefik 日志：`docker logs traefik`
2. 服务状态：`docker-compose ps`
3. 网络连接：`docker network inspect frontend`
