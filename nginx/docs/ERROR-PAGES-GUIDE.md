# Nginx 错误页面配置指南

本文档说明如何配置和使用统一的错误页面服务。

## 📋 目录

- [概述](#概述)
- [配置方案](#配置方案)
- [使用方法](#使用方法)
- [测试验证](#测试验证)
- [自定义配置](#自定义配置)
- [常见问题](#常见问题)

---

## 概述

### 架构说明

本配置使用独立的 `error-pages` 容器来提供统一的错误页面：

```
┌─────────────┐      ┌─────────────┐      ┌──────────────────┐
│   用户请求   │ ───> │   Nginx     │ ───> │  Backend Service │
└─────────────┘      └─────────────┘      └──────────────────┘
                           │
                           │ (发生错误)
                           ↓
                     ┌─────────────┐
                     │ error-pages │  (内部代理)
                     │  容器:8080  │
                     └─────────────┘
```

### 功能特点

✅ **统一美观的错误页面**
- 所有 4xx 和 5xx 错误码统一样式
- 由专门的 error-pages 服务提供
- 支持多语言和主题定制

✅ **自动处理所有错误**
- 400-451 (客户端错误)
- 500-511 (服务器错误)

✅ **禁止缓存错误页面**
- 确保用户始终看到最新状态
- 避免误导性的缓存错误

✅ **安全性**
- 使用 `internal` 指令防止外部直接访问
- 只能通过内部错误重定向触发

---

## 配置方案

### 方案对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **方案 1：全局配置** ⭐ | 多个站点 | 配置一次，全站生效 | 需要在每个 server 块引入 location |
| **方案 2：单站点配置** | 单个站点 | 配置简单直接 | 每个站点需要重复配置 |
| **方案 3：混合配置** | 部分站点 | 灵活可控 | 配置稍复杂 |

---

## 使用方法

### 方案 1：全局配置（推荐）⭐

**适用场景：** 所有站点都使用统一错误页面

#### 步骤 1：HTTP 块配置

在 `nginx.conf` 的 `http {}` 块中添加：

```nginx
http {
    # 其他配置...
    
    # 全局错误页面配置
    include /etc/nginx/snippets/error-pages-global.conf;
    
    # server 块...
}
```

**文件内容：** `error-pages-global.conf`
```nginx
# 定义所有错误码的重定向目标
error_page 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 416 417 418 421 422 423 424 425 426 428 429 431 451 /error-pages/$status;
error_page 500 501 502 503 504 505 506 507 508 510 511 /error-pages/$status;
```

#### 步骤 2：Server 块配置

在每个 `server {}` 块中添加：

```nginx
server {
    listen 443 ssl;
    server_name example.com;
    
    # 其他配置...
    
    # 错误页面 location（必须）
    include /etc/nginx/snippets/error-pages-location.conf;
    
    # 应用配置...
    location / {
        proxy_pass http://backend;
    }
}
```

**文件内容：** `error-pages-location.conf`
```nginx
location /error-pages/ {
    add_header Cache-Control "no-store, no-cache, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";
    
    proxy_pass http://error-pages:8080/$status;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    internal;
}
```

#### ✅ 优点
- 配置一次，所有站点自动生效
- HTTP 块的 `error_page` 指令会被所有 server 继承
- 便于统一管理和维护

#### ⚠️ 注意事项
- 每个 server 块必须包含 `error-pages-location.conf`
- 否则错误页面无法正常代理到 error-pages 服务

---

### 方案 2：单站点配置（简单）

**适用场景：** 只有少数站点需要错误页面，或需要独立配置

#### 直接在 Server 块引入完整配置

```nginx
server {
    listen 443 ssl;
    server_name example.com;
    
    # 直接引入完整配置（包含 error_page 和 location）
    include /etc/nginx/snippets/error-pages.conf;
    
    # 应用配置...
    location / {
        proxy_pass http://backend;
    }
}
```

**文件内容：** `error-pages.conf`（已有，无需修改）

#### ✅ 优点
- 配置简单，一行搞定
- 适合单个站点或快速测试

#### ⚠️ 缺点
- 每个站点需要单独配置
- `error_page` 指令在每个 server 块重复定义

---

### 方案 3：混合配置（灵活）

**适用场景：** 部分站点使用统一错误页面，部分站点自定义

#### HTTP 块：只在需要的站点启用

```nginx
http {
    # 不在 HTTP 块全局配置
    
    # 站点 A：使用统一错误页面
    server {
        server_name site-a.com;
        include /etc/nginx/snippets/error-pages.conf;
    }
    
    # 站点 B：自定义错误页面
    server {
        server_name site-b.com;
        error_page 404 /custom-404.html;
        error_page 500 502 503 504 /custom-50x.html;
        
        location = /custom-404.html {
            root /var/www/site-b;
        }
    }
    
    # 站点 C：不配置错误页面（使用 Nginx 默认）
    server {
        server_name site-c.com;
        # 无错误页面配置
    }
}
```

---

## 测试验证

### 1. 测试 404 错误

```bash
# 访问不存在的页面
curl -I https://your-domain.com/non-existent-page

# 期望结果：
# HTTP/2 404
# Content-Type: text/html
```

### 2. 测试 403 错误

```bash
# 访问被拒绝的资源
curl -I https://your-domain.com/.env

# 期望结果：
# HTTP/2 403
```

### 3. 测试 500 错误

可以临时在应用中触发 500 错误，或者：

```bash
# 如果后端服务停止
curl -I https://your-domain.com/

# 期望结果：
# HTTP/2 502 或 503
```

### 4. 验证错误页面来源

```bash
# 查看完整响应
curl -v https://your-domain.com/non-existent-page 2>&1 | grep -A 20 "HTTP"

# 检查是否包含 error-pages 容器返回的 HTML
```

### 5. 验证缓存头

```bash
curl -I https://your-domain.com/non-existent-page | grep -E "(Cache-Control|Pragma|Expires)"

# 期望结果：
# Cache-Control: no-store, no-cache, must-revalidate
# Pragma: no-cache
# Expires: 0
```

### 6. 测试 internal 指令

```bash
# 尝试直接访问 /error-pages/ 路径（应该被拒绝）
curl -I https://your-domain.com/error-pages/404

# 期望结果：
# HTTP/2 404（不是 error-pages 服务的响应）
```

---

## 自定义配置

### 自定义错误码处理

如果只想处理特定错误码：

```nginx
# 只处理常见错误
error_page 404 /error-pages/$status;
error_page 500 502 503 504 /error-pages/$status;

location /error-pages/ {
    proxy_pass http://error-pages:8080/$status;
    internal;
}
```

### 不同站点使用不同错误页面服务

```nginx
# 站点 A
server {
    server_name site-a.com;
    error_page 404 /error-pages/$status;
    
    location /error-pages/ {
        proxy_pass http://error-pages-theme1:8080/$status;
        internal;
    }
}

# 站点 B
server {
    server_name site-b.com;
    error_page 404 /error-pages/$status;
    
    location /error-pages/ {
        proxy_pass http://error-pages-theme2:8080/$status;
        internal;
    }
}
```

### 添加额外的响应头

```nginx
location /error-pages/ {
    add_header Cache-Control "no-store, no-cache, must-revalidate";
    add_header X-Error-Source "error-pages-service";
    add_header X-Error-Code "$status";
    
    proxy_pass http://error-pages:8080/$status;
    internal;
}
```

### 记录错误日志

```nginx
location /error-pages/ {
    # 启用错误页面访问日志（默认 off）
    access_log /var/log/nginx/error-pages.log;
    
    proxy_pass http://error-pages:8080/$status;
    internal;
}
```

---

## 常见问题

### Q1: 为什么错误页面显示 Nginx 默认页面？

**可能原因：**
1. 未在 server 块引入 `error-pages-location.conf`
2. error-pages 容器未运行
3. Docker 网络配置问题

**解决方法：**
```bash
# 检查容器状态
docker compose ps error-pages

# 检查 Nginx 配置
docker compose exec nginx nginx -t

# 查看错误日志
docker compose logs error-pages --tail=50
```

### Q2: 如何禁用特定站点的统一错误页面？

**方法 1：覆盖 error_page 指令**
```nginx
server {
    server_name example.com;
    
    # 覆盖全局配置
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /404.html {
        root /var/www/html;
    }
}
```

**方法 2：使用默认错误页面**
```nginx
server {
    server_name example.com;
    
    # 重置 error_page 指令（使用 Nginx 默认）
    error_page 404 =404;
    error_page 500 =500;
}
```

### Q3: error-pages 容器如何配置？

**docker-compose.yml 示例：**
```yaml
services:
  error-pages:
    image: tarampampam/error-pages:latest
    container_name: error-pages
    environment:
      TEMPLATE_NAME: l7-dark  # 主题名称
    restart: unless-stopped
    networks:
      - nginx-network
```

**可用主题：**
- `ghost` - Ghost 风格
- `l7-light` - 浅色主题
- `l7-dark` - 深色主题
- `shuffle` - 随机主题
- `noise` - 噪点风格
- `hacker-terminal` - 黑客终端风格

### Q4: 如何查看错误页面是否被正确代理？

```bash
# 方法 1：检查响应头
curl -I https://your-domain.com/non-existent 2>&1 | grep -i server

# 方法 2：查看完整响应
curl https://your-domain.com/404 2>&1 | head -20

# 方法 3：查看 Nginx 日志
docker compose logs nginx --tail=50 | grep "error-pages"
```

### Q5: 错误页面可以使用 HTTPS 吗？

可以！如果 error-pages 服务支持 HTTPS：

```nginx
location /error-pages/ {
    proxy_pass https://error-pages:8443/$status;
    proxy_ssl_verify off;  # 如果使用自签名证书
    internal;
}
```

### Q6: 如何处理 upstream 超时错误？

```nginx
# 添加超时配置
location /error-pages/ {
    proxy_pass http://error-pages:8080/$status;
    proxy_connect_timeout 5s;
    proxy_send_timeout 5s;
    proxy_read_timeout 5s;
    internal;
}
```

---

## 最佳实践

### 1. 推荐配置结构

```
nginx/
├── nginx.conf                           # 主配置（引入 error-pages-global.conf）
├── snippets/
│   ├── error-pages-global.conf         # HTTP 块级别（error_page 指令）
│   ├── error-pages-location.conf       # Server 块级别（location 指令）
│   └── error-pages.conf                # 完整配置（向后兼容）
└── sites/
    ├── site-a.conf                     # 引入 error-pages-location.conf
    ├── site-b.conf                     # 引入 error-pages-location.conf
    └── site-c.conf                     # 自定义错误页面（不引入）
```

### 2. 配置检查清单

部署前检查：
- [ ] error-pages 容器正常运行
- [ ] HTTP 块引入了 `error-pages-global.conf`（全局方案）
- [ ] 每个 server 块引入了 `error-pages-location.conf`
- [ ] 配置语法测试通过：`nginx -t`
- [ ] 测试各种错误码（404, 403, 500 等）
- [ ] 验证 `internal` 指令生效
- [ ] 检查缓存头正确设置

### 3. 性能优化

```nginx
location /error-pages/ {
    # 启用 keepalive
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    
    # 缓冲优化
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    
    proxy_pass http://error-pages:8080/$status;
    internal;
}
```

### 4. 监控建议

```bash
# 定期检查错误页面访问量
docker compose logs nginx | grep "error-pages" | wc -l

# 统计错误码分布
docker compose logs nginx | grep -oP '"\s\K\d{3}' | grep -E "^(4|5)" | sort | uniq -c | sort -rn

# 监控 error-pages 容器健康
docker compose exec error-pages wget -q -O- http://localhost:8080/healthz
```

---

## 故障排除

### 问题：错误页面显示空白

**检查步骤：**
```bash
# 1. 检查容器日志
docker compose logs error-pages --tail=50

# 2. 手动测试 error-pages 服务
docker compose exec nginx curl -v http://error-pages:8080/404

# 3. 检查 Docker 网络
docker network inspect local_default | grep -A 5 error-pages
```

### 问题：错误页面不显示样式

**可能原因：**
- CSP (Content-Security-Policy) 头阻止
- 静态资源路径问题

**解决方法：**
```nginx
location /error-pages/ {
    # 允许错误页面加载资源
    add_header Content-Security-Policy "default-src 'self' 'unsafe-inline'";
    
    proxy_pass http://error-pages:8080/$status;
    internal;
}
```

---

## 相关文档

- [Nginx 官方文档 - error_page](http://nginx.org/en/docs/http/ngx_http_core_module.html#error_page)
- [error-pages 容器文档](https://github.com/tarampampam/error-pages)
- [Nginx 主配置](../nginx.conf)
- [安全配置指南](SECURITY-CONFIG.md)

---

## 更新日志

### 2025-01-11
- ✅ 创建初始文档
- ✅ 添加全局配置方案
- ✅ 拆分 error-pages-global.conf 和 error-pages-location.conf
- ✅ 更新 nginx.conf 使用全局配置
- ✅ 保持 error-pages.conf 向后兼容

---

**最后更新：** 2025-01-11  
**维护人员：** DevOps Team  
**版本：** 1.0