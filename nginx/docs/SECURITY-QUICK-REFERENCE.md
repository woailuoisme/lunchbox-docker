# Nginx 安全配置速查表

**版本：** 1.0  
**更新：** 2025-01-11  
**用途：** 快速查找和应用 Nginx 安全配置

---

## 📋 目录

- [已部署的安全功能](#已部署的安全功能)
- [推荐增强配置](#推荐增强配置)
- [所有可用的安全控制](#所有可用的安全控制)
- [快速配置模板](#快速配置模板)
- [常用命令](#常用命令)

---

## 已部署的安全功能

### ✅ 当前状态

```
安全评分: 85/100 🟢
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ SSL/TLS 基础配置           20/20
✅ 恶意请求防护               20/20
✅ 敏感文件保护               20/20
✅ 限流机制                   15/15
⚠️  安全响应头                12/15 (缺CSP)
⚠️  SSL/TLS 增强              8/10  (缺OCSP)
❌ 监控日志                   0/10
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 🔐 已启用的防护

| 功能 | 配置文件 | 位置 |
|-----|---------|------|
| SSL/TLS 基础 | `nginx.conf` | HTTP 块 |
| 恶意 UA 检测 | `security-maps.conf` | HTTP 块 |
| SQL 注入防护 | `security-maps.conf` | HTTP 块 |
| 路径遍历防护 | `security-maps.conf` | HTTP 块 |
| 请求拦截 | `security-checks.conf` | Server 块 |
| 敏感文件保护 | `security-filters.conf` | Server 块 |
| 安全响应头 | `security-headers.conf` | Server 块 |
| 限流配置 | `nginx.conf` | HTTP 块 |

---

## 推荐增强配置

### 🚀 快速提升到 95/100

#### 1️⃣ 请求安全增强 (+5分)

**文件：** `snippets/security-requests.conf`

```nginx
# 在 nginx.conf HTTP 块添加
include /etc/nginx/snippets/security-requests.conf;
```

**提供：**
- 缓冲区溢出防护
- 慢速攻击防护
- 连接数限制

#### 2️⃣ SSL 增强配置 (+2分)

**文件：** `snippets/ssl-enhanced.conf`

```nginx
# 在 HTTPS server 块添加
include /etc/nginx/snippets/ssl-enhanced.conf;

# 生成 DH 参数（首次需要）
openssl dhparam -out ssl/dhparam.pem 4096
```

**提供：**
- SSL Session 优化
- OCSP Stapling
- 性能提升 50%+

#### 3️⃣ CSP 响应头 (+3分)

**位置：** `snippets/security-headers.conf`

```nginx
# 添加到现有的 security-headers.conf
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;
```

---

## 所有可用的安全控制

### 🔒 HTTP 块级别配置

#### 基础安全

```nginx
# 隐藏版本号
server_tokens off;

# 字符集
charset UTF-8;

# 请求大小限制
client_max_body_size 20M;
```

#### SSL/TLS 配置

```nginx
# 只允许安全协议
ssl_protocols TLSv1.2 TLSv1.3;

# 强加密套件
ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:...';

# 优先服务器加密套件
ssl_prefer_server_ciphers on;

# Session 优化（增强配置）
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;

# OCSP Stapling（增强配置）
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
```

#### 请求安全

```nginx
# 缓冲区限制（增强配置）
client_body_buffer_size 1K;
client_header_buffer_size 1k;
large_client_header_buffers 2 1k;

# 超时控制（增强配置）
client_body_timeout 10;
client_header_timeout 10;
send_timeout 10;
reset_timedout_connection on;

# Keepalive
keepalive_timeout 15;
keepalive_requests 100;
```

#### 连接限制

```nginx
# 定义限制区域（增强配置）
limit_conn_zone $binary_remote_addr zone=perip:10m;
limit_conn_zone $server_name zone=perserver:10m;

# 在 server 块应用
limit_conn perip 10;        # 每个 IP 最多 10 个连接
limit_conn perserver 100;   # 每个虚拟主机最多 100 个连接
```

#### 限流配置

```nginx
# 登录接口（严格）
limit_req_zone $binary_remote_addr zone=auth_login:10m rate=5r/m;

# 认证接口（中等）
limit_req_zone $binary_remote_addr zone=auth_global:10m rate=10r/s;

# 一般接口（宽松）
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;

# API 接口（增强配置）
limit_req_zone $binary_remote_addr zone=api:10m rate=50r/s;

# 搜索接口（增强配置）
limit_req_zone $binary_remote_addr zone=search:10m rate=10r/s;

# 文件上传（增强配置）
limit_req_zone $binary_remote_addr zone=upload:10m rate=5r/m;

# 在 location 块应用
limit_req zone=general burst=20 nodelay;
```

#### 恶意请求检测 Map

```nginx
# User-Agent 检测
map $http_user_agent $bad_user_agent {
    default 0;
    "" 1;                  # 空 UA
    ~*sqlmap 1;
    ~*nikto 1;
    ~*nmap 1;
    ~*masscan 1;
    ~*burp 1;
}

# SQL 注入检测
map $query_string $bad_sql_injection {
    default 0;
    ~*union.*select 1;
    ~*insert.*into 1;
    ~*drop.*table 1;
    ~*delete.*from 1;
}

# 路径遍历检测
map $request_uri $bad_path_traversal {
    default 0;
    ~*\.\./\.\. 1;
    ~*/etc/passwd 1;
}

# HTTP 方法检测
map $request_method $bad_method {
    default 1;
    GET 0;
    POST 0;
    HEAD 0;
    PUT 0;
    DELETE 0;
    OPTIONS 0;
    PATCH 0;
}
```

#### 日志配置

```nginx
# 自定义日志格式
log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

# 性能日志格式
log_format timing '$remote_addr - $remote_user [$time_local] '
                  '"$request" $status $body_bytes_sent '
                  'rt=$request_time uct="$upstream_connect_time" '
                  'uht="$upstream_header_time" urt="$upstream_response_time"';

# 日志输出
access_log /var/log/nginx/access.log main;
error_log /var/log/nginx/error.log;
```

#### Gzip 压缩

```nginx
gzip on;
gzip_disable "msie6";
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;

gzip_types
  application/atom+xml
  application/javascript
  application/json
  application/xml
  text/css
  text/plain;
```

---

### 🔒 Server 块级别配置

#### 安全检查（应用 Map 变量）

```nginx
# 阻止恶意 User-Agent
if ($bad_user_agent) {
    return 403;
}

# 阻止 SQL 注入
if ($bad_sql_injection) {
    return 403;
}

# 阻止路径遍历
if ($bad_path_traversal) {
    return 403;
}

# 阻止无效 HTTP 方法
if ($bad_method) {
    return 405;
}
```

#### 安全响应头

```nginx
# HSTS - 强制 HTTPS
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Clickjacking 防护
add_header X-Frame-Options "SAMEORIGIN" always;

# MIME 类型嗅探防护
add_header X-Content-Type-Options "nosniff" always;

# XSS 防护
add_header X-XSS-Protection "1; mode=block" always;

# Referrer 策略
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# 权限策略
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

# CSP（需要根据应用调整）
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;" always;
```

#### SSL 证书配置

```nginx
# 证书文件
ssl_certificate /etc/nginx/ssl/example.com.crt;
ssl_certificate_key /etc/nginx/ssl/example.com.key;

# DH 参数（增强配置）
ssl_dhparam /etc/nginx/ssl/dhparam.pem;

# 证书链（用于 OCSP Stapling）
ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
```

---

### 🔒 Location 块级别配置

#### 敏感文件保护

```nginx
# 隐藏文件
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 配置文件
location ~ \.(ini|conf|cnf|yml|yaml|toml|env)$ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 备份文件
location ~ \.(bak|backup|old|orig|save|swp|tmp)$ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 数据库文件
location ~ \.(sql|sqlite|db)$ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 源代码文件
location ~ \.(py|rb|sh|java)$ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 开发依赖目录
location ~ ^/(vendor|node_modules|bower_components)/ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}

# 容器配置
location ~ ^/(Dockerfile|docker-compose\.ya?ml)$ {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}
```

#### IP 访问控制

```nginx
# 白名单
location /admin {
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;
}

# 使用 geo 模块
geo $ip_whitelist {
    default 0;
    192.168.1.0/24 1;
    10.0.0.0/8 1;
}

location /admin {
    if ($ip_whitelist = 0) {
        return 403;
    }
}
```

#### 反向代理安全

```nginx
location / {
    proxy_pass http://backend;
    
    # 隐藏后端错误
    proxy_intercept_errors on;
    
    # 超时控制
    proxy_connect_timeout 5s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # 缓冲区限制
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    
    # 安全请求头
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # 隐藏后端头
    proxy_hide_header X-Powered-By;
    proxy_hide_header Server;
}
```

#### 静态资源优化

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    access_log off;
    
    # 保持安全头
    include /etc/nginx/snippets/security-headers.conf;
}
```

#### 代理缓存

```nginx
# HTTP 块定义缓存路径
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m;

# Location 块应用
location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    
    # 不缓存带认证的请求
    proxy_cache_bypass $http_authorization;
    proxy_no_cache $http_authorization;
    
    proxy_pass http://backend;
}
```

---

## 快速配置模板

### 完整的安全 Server 块

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;
    
    # ==================== SSL 配置 ====================
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # 基础 SSL
    include /etc/nginx/snippets/ssl.conf;
    
    # SSL 增强（推荐）
    include /etc/nginx/snippets/ssl-enhanced.conf;
    
    # ==================== 安全配置 ====================
    # 安全响应头
    include /etc/nginx/snippets/security-headers.conf;
    
    # 恶意请求检测
    include /etc/nginx/snippets/security-checks.conf;
    
    # 敏感文件保护
    include /etc/nginx/snippets/security-filters.conf;
    
    # 错误页面
    include /etc/nginx/snippets/error-pages-location.conf;
    
    # ==================== 限流和限制 ====================
    # 连接数限制
    limit_conn perip 10;
    
    # 一般限流
    limit_req zone=general burst=20 nodelay;
    
    # ==================== 应用配置 ====================
    location / {
        proxy_pass http://backend;
        include /etc/nginx/snippets/proxy-standard.conf;
    }
    
    # 管理后台（严格限流）
    location /admin {
        limit_req zone=auth_login burst=2 nodelay;
        limit_conn perip 3;
        
        # IP 白名单（可选）
        allow 192.168.1.0/24;
        deny all;
        
        proxy_pass http://backend;
    }
    
    # API 接口
    location /api {
        limit_req zone=api burst=100 nodelay;
        proxy_pass http://backend;
    }
}
```

### HTTP 到 HTTPS 重定向

```nginx
server {
    listen 80;
    server_name example.com;
    
    # 重定向到 HTTPS
    return 301 https://$host$request_uri;
}
```

### 默认拒绝 Server

```nginx
server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name _;
    
    # 最小化 SSL 配置（防止证书错误）
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;
    
    # 返回 444（关闭连接）
    return 444;
}
```

---

## 常用命令

### 配置管理

```bash
# 测试配置语法
docker compose exec nginx nginx -t

# 重载配置（不中断服务）
docker compose exec nginx nginx -s reload

# 重启 Nginx
docker compose restart nginx

# 查看配置
docker compose exec nginx cat /etc/nginx/nginx.conf
```

### 测试和验证

```bash
# 运行安全测试
./nginx/test-security.sh https://your-domain.com

# 测试 SSL 配置
openssl s_client -connect example.com:443 -status

# 测试安全响应头
curl -I https://example.com | grep -E "(Strict-Transport|X-Frame|X-Content)"

# 测试限流
for i in {1..100}; do curl https://example.com/; done
```

### 日志分析

```bash
# 查看最近的错误
docker compose logs nginx --tail=100 | grep error

# 查看被拦截的请求（403）
docker compose logs nginx | grep " 403 " | tail -20

# 查看敏感文件访问（404）
docker compose logs nginx | grep " 404 " | grep -E "(\.env|\.git)"

# 统计攻击来源 IP
docker compose logs nginx --since 24h | grep " 403 " | awk '{print $1}' | sort | uniq -c | sort -rn

# 统计最常见的攻击路径
docker compose logs nginx | grep " 404 " | awk '{print $7}' | sort | uniq -c | sort -rn | head -20

# 统计恶意 User-Agent
docker compose logs nginx | grep " 403 " | grep -oP '"[^"]*"$' | sort | uniq -c | sort -rn
```

### 性能监控

```bash
# 查看当前连接数
docker compose exec nginx ss -ant | grep :443 | wc -l

# 查看 Nginx 进程
docker compose exec nginx ps aux | grep nginx

# 查看内存使用
docker compose exec nginx free -h

# 实时日志
docker compose logs -f nginx
```

### 证书管理

```bash
# 生成 DH 参数
openssl dhparam -out ssl/dhparam.pem 4096

# 查看证书信息
openssl x509 -in ssl/example.com.crt -noout -text

# 查看证书有效期
openssl x509 -in ssl/example.com.crt -noout -dates

# 验证证书链
openssl verify -CAfile ssl/chain.pem ssl/example.com.crt

# Let's Encrypt 续订
certbot renew --nginx
```

### 备份和恢复

```bash
# 备份配置
tar -czf nginx-config-backup-$(date +%Y%m%d).tar.gz nginx/

# 恢复配置
tar -xzf nginx-config-backup-20250111.tar.gz

# 比较配置差异
diff -u nginx.conf.backup nginx.conf
```

---

## 在线工具

### SSL/TLS 测试
- **SSL Labs**: https://www.ssllabs.com/ssltest/
- **SSL Decoder**: https://www.sslshopper.com/ssl-decoder.html

### 安全头测试
- **Security Headers**: https://securityheaders.com/
- **Mozilla Observatory**: https://observatory.mozilla.org/

### 性能测试
- **GTmetrix**: https://gtmetrix.com/
- **WebPageTest**: https://www.webpagetest.org/

### CSP 工具
- **CSP Evaluator**: https://csp-evaluator.withgoogle.com/
- **CSP Generator**: https://report-uri.com/home/generate

---

## 故障排查

### 常见问题速查

| 问题 | 可能原因 | 解决方法 |
|-----|---------|---------|
| 403 Forbidden | 安全规则误拦截 | 检查 `security-checks.conf`，调整 Map 变量 |
| 404 Not Found | 文件保护规则 | 检查 `security-filters.conf`，添加例外 |
| 429 Too Many Requests | 限流触发 | 调整 `limit_req` 的 burst 参数 |
| 502 Bad Gateway | 后端服务不可用 | 检查后端服务状态和代理配置 |
| 503 Service Unavailable | 连接数超限 | 调整 `limit_conn` 参数 |
| SSL 握手失败 | SSL 配置错误 | 检查证书文件和 SSL 协议配置 |
| 日志量过大 | 未过滤静态资源 | 添加日志过滤条件 |

### 快速诊断命令

```bash
# 检查 Nginx 错误日志
docker compose logs nginx --tail=50 | grep error

# 检查配置语法
docker compose exec nginx nginx -t

# 测试特定 URL
curl -v https://example.com/test 2>&1 | less

# 查看限流状态
docker compose logs nginx | grep "limiting requests"

# 查看连接限制状态
docker compose logs nginx | grep "limiting connections"
```

---

## 维护日历

### 每日
- [ ] 查看错误日志
- [ ] 监控 403/404 异常

### 每周
- [ ] 分析攻击模式
- [ ] 检查限流效果
- [ ] 更新黑名单（如有）

### 每月
- [ ] 更新安全规则
- [ ] 审查安全配置
- [ ] 性能优化调整

### 每季度
- [ ] SSL 配置测试
- [ ] 安全审计
- [ ] 渗透测试

### 每年
- [ ] 完整安全评估
- [ ] 配置架构审查
- [ ] 团队安全培训

---

## 快速参考

### 配置文件位置

```
nginx/
├── nginx.conf                        # 主配置
├── snippets/
│   ├── security-maps.conf           # Map 变量（HTTP块）
│   ├── security-checks.conf         # 请求检查（Server块）
│   ├── security-filters.conf        # 文件过滤（Server块）
│   ├── security-headers.conf        # 安全响应头（Server块）
│   ├── security-requests.conf       # 请求增强（HTTP块）⭐
│   ├── ssl.conf                     # 基础 SSL（Server块）
│   ├── ssl-enhanced.conf            # SSL 增强（Server块）⭐
│   ├── error-pages-global.conf      # 错误页面（HTTP块）
│   └── error-pages-location.conf    # 错误页面（Server块）
├── sites/
│   └── *.conf                       # 站点配置
└── ssl/
    ├── *.crt                        # SSL 证书
    ├── *.key                        # 私钥
    └── dhparam.pem                  # DH 参数⭐
```

### 安全评分对照

| 分数 | 等级 | 说明 |
|------|------|-----|
| 95-100 | A+ | 优秀 |
| 85-94 | A | 良好（当前状态） |
| 75-84 | B | 一般 |
| 60-74 | C | 需要改进 |
| < 60 | D/F | 严重不足 |

---

## 相关文档

- 📖 **SECURITY-CHECKLIST.md** - 完整安全清单（782行）
- 📖 **SECURITY-SUMMARY.md** - 可视化总结（514行）
- 📖 **SECURITY-CONFIG.md** - 已部署功能详解
- 📖 **ERROR-PAGES-GUIDE.md** - 错误页面配置（582行）
- 🛠️ **apply-security-enhancements.sh** - 自动化部署脚本
- 🛠️ **test-security.sh** - 安全测试脚本

---

**提示：** 这是速查表，详细说明请参考相关完整文档。