# Certbot SSL 证书管理

本目录包含支持阿里云和 Cloudflare DNS 验证的 Certbot 配置，可以自动申请和续签 SSL 证书。

## 功能特性

- 支持 Cloudflare 和阿里云 DNS 验证
- 自动申请通配符证书（*.domain.com）
- 自动证书续签
- 容器化部署
- 环境变量配置

## 文件说明

```
certbot/
├── Dockerfile          # Certbot 容器构建文件
├── start.sh            # 启动脚本
├── cloudflare.ini      # Cloudflare API 凭据
├── aliyun.ini          # 阿里云 API 凭据
├── conf/               # 证书存储目录
└── logs/               # 日志目录
```

## 配置步骤

### 1. 环境变量配置

在 `.env` 文件中配置以下变量：

```bash
# DNS 提供商选择
CERTBOT_DNS_PROVIDER=cloudflare  # 或 aliyun

# 域名和邮箱
DOMAIN=your-domain.com
CERTBOT_EMAIL=your-email@example.com

# 续签间隔（秒）
CERTBOT_RENEW_INTERVAL=43200  # 12小时
```

### 2. DNS 提供商凭据配置

#### Cloudflare 配置

编辑 `cloudflare.ini` 文件：

```ini
# Cloudflare API Token（推荐）
dns_cloudflare_api_token = your_api_token_here
```

获取 API Token：
1. 登录 Cloudflare 控制台
2. 进入 "My Profile" > "API Tokens"
3. 创建自定义 Token，权限设置：
   - Zone:Zone:Read
   - Zone:DNS:Edit
   - 包含特定区域：your-domain.com

#### 阿里云配置

编辑 `aliyun.ini` 文件：

```ini
# 阿里云 AccessKey
dns_aliyun_access_key_id = your_access_key_id
dns_aliyun_access_key_secret = your_access_key_secret
```

获取 AccessKey：
1. 登录阿里云控制台
2. 进入 "访问控制" > "用户"
3. 创建 RAM 用户，授予 DNS 解析权限
4. 生成 AccessKey

### 3. 启动服务

```bash
# 构建并启动 Certbot 容器
docker-compose up -d certbot

# 查看日志
docker-compose logs -f certbot
```

## 使用说明

### 切换 DNS 提供商

修改 `.env` 文件中的 `CERTBOT_DNS_PROVIDER` 变量：

```bash
# 使用 Cloudflare
CERTBOT_DNS_PROVIDER=cloudflare

# 使用阿里云
CERTBOT_DNS_PROVIDER=aliyun
```

然后重启容器：

```bash
docker-compose restart certbot
```

### 手动申请证书

```bash
# 进入容器
docker-compose exec certbot bash

# 手动申请证书
certbot certonly \
  --authenticator dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  --domains "your-domain.com" \
  --domains "*.your-domain.com"
```

### 手动续签证书

```bash
# 进入容器
docker-compose exec certbot bash

# 续签所有证书
certbot renew
```

## 证书文件位置

证书文件存储在 `./certbot/conf/live/your-domain.com/` 目录下：

- `fullchain.pem` - 完整证书链（用于 nginx ssl_certificate）
- `privkey.pem` - 私钥文件（用于 nginx ssl_certificate_key）
- `cert.pem` - 证书文件
- `chain.pem` - 证书链文件

## Nginx 配置示例

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com *.your-domain.com;
    
    ssl_certificate /etc/nginx/ssl/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/your-domain.com/privkey.pem;
    
    # 其他配置...
}
```

## 故障排除

### 常见问题

1. **DNS 验证失败**
   - 检查 DNS 提供商凭据是否正确
   - 确认 API 权限是否足够
   - 检查域名 DNS 解析是否正常

2. **证书申请失败**
   - 查看容器日志：`docker-compose logs certbot`
   - 检查网络连接
   - 确认域名所有权

3. **容器启动失败**
   - 检查凭据文件是否存在
   - 确认环境变量配置正确
   - 查看构建日志

### 调试命令

```bash
# 查看容器状态
docker-compose ps certbot

# 查看实时日志
docker-compose logs -f certbot

# 进入容器调试
docker-compose exec certbot bash

# 测试 DNS 验证
docker-compose exec certbot certbot --help dns-cloudflare
```

## 安全注意事项

1. **保护凭据文件**
   - 设置适当的文件权限（600）
   - 不要将凭据文件提交到版本控制系统
   - 定期轮换 API 密钥

2. **最小权限原则**
   - 只授予必要的 DNS 权限
   - 使用 RAM 子账号（阿里云）
   - 限制 API Token 作用域（Cloudflare）

3. **监控和日志**
   - 定期检查证书有效期
   - 监控续签日志
   - 设置证书过期告警