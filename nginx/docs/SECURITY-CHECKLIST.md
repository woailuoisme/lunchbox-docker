# Nginx 安全配置完整清单

**最后更新：** 2025-01-11  
**适用版本：** Nginx 1.20+

---

## 📋 目录

- [当前已配置的安全措施](#当前已配置的安全措施)
- [推荐增强配置](#推荐增强配置)
- [高级安全配置](#高级安全配置)
- [监控和日志](#监控和日志)
- [性能与安全平衡](#性能与安全平衡)
- [合规性检查](#合规性检查)

---

## 当前已配置的安全措施

### ✅ 1. 基础安全配置

#### 1.1 隐藏服务器信息
```nginx
server_tokens off;
```
**作用：** 隐藏 Nginx 版本号，防止针对特定版本的攻击  
**状态：** ✅ 已启用  
**位置：** `nginx.conf` HTTP 块

#### 1.2 SSL/TLS 配置
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:...';
```
**作用：** 只允许安全的 TLS 协议和加密套件  
**状态：** ✅ 已启用  
**位置：** `nginx.conf` HTTP 块

### ✅ 2. 恶意请求防护

#### 2.1 恶意 User-Agent 检测
```nginx
map $http_user_agent $bad_user_agent {
    ~*sqlmap 1;
    ~*nikto 1;
    ~*nmap 1;
    # ...
}
```
**作用：** 识别并拦截扫描工具和恶意爬虫  
**状态：** ✅ 已启用  
**位置：** `snippets/security-maps.conf`

#### 2.2 SQL 注入防护
```nginx
map $query_string $bad_sql_injection {
    ~*union.*select 1;
    ~*insert.*into 1;
    ~*drop.*table 1;
    # ...
}
```
**作用：** 检测并阻止 SQL 注入尝试  
**状态：** ✅ 已启用  
**位置：** `snippets/security-maps.conf`

#### 2.3 路径遍历防护
```nginx
map $request_uri $bad_path_traversal {
    ~*\.\./\.\. 1;
    ~*/etc/passwd 1;
    # ...
}
```
**作用：** 防止目录遍历攻击  
**状态：** ✅ 已启用  
**位置：** `snippets/security-maps.conf`

#### 2.4 HTTP 方法限制
```nginx
map $request_method $bad_method {
    default 1;
    GET 0;
    POST 0;
    HEAD 0;
    # ...
}
```
**作用：** 只允许标准的 HTTP 方法  
**状态：** ✅ 已启用  
**位置：** `snippets/security-maps.conf`

### ✅ 3. 敏感文件保护

#### 3.1 隐藏文件保护
```nginx
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
    return 404;
}
```
**作用：** 阻止访问 `.env`, `.git`, `.htaccess` 等  
**状态：** ✅ 已启用  
**位置：** `snippets/security-filters.conf`

#### 3.2 配置文件保护
```nginx
location ~ \.(ini|conf|cnf|yml|yaml|toml|env|config)$ {
    deny all;
}
```
**作用：** 阻止访问配置文件  
**状态：** ✅ 已启用  
**位置：** `snippets/security-filters.conf`

#### 3.3 备份文件保护
```nginx
location ~ \.(bak|backup|old|orig|save|swp|swo|tmp)$ {
    deny all;
}
```
**作用：** 阻止访问备份文件  
**状态：** ✅ 已启用  
**位置：** `snippets/security-filters.conf`

### ✅ 4. 安全响应头

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
```
**作用：** 提供多层浏览器安全防护  
**状态：** ✅ 已启用  
**位置：** `snippets/security-headers.conf`

### ✅ 5. 限流配置

```nginx
# 登录接口限流 - 5请求/分钟
limit_req_zone $binary_remote_addr zone=auth_login:10m rate=5r/m;

# 认证接口限流 - 10请求/秒
limit_req_zone $binary_remote_addr zone=auth_global:10m rate=10r/s;

# 一般接口限流 - 30请求/秒
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
```
**作用：** 防止暴力破解和 DDoS 攻击  
**状态：** ✅ 已配置（需要在站点中应用）  
**位置：** `nginx.conf` HTTP 块

### ✅ 6. 请求大小限制

```nginx
client_max_body_size 20M;
```
**作用：** 限制上传文件大小，防止资源耗尽  
**状态：** ✅ 已启用  
**位置：** `nginx.conf` HTTP 块

---

## 推荐增强配置

### 🔧 1. 请求安全增强

#### 1.1 缓冲区溢出防护
```nginx
# 添加到 http 块
client_body_buffer_size 1K;
client_header_buffer_size 1k;
large_client_header_buffers 2 1k;
```
**优先级：** ⭐⭐⭐  
**作用：** 防止缓冲区溢出攻击  
**位置：** `nginx.conf` HTTP 块

#### 1.2 请求超时控制
```nginx
# 添加到 http 块
client_body_timeout 10;
client_header_timeout 10;
send_timeout 10;
```
**优先级：** ⭐⭐⭐  
**作用：** 防止慢速攻击（Slowloris）  
**位置：** `nginx.conf` HTTP 块

#### 1.3 连接数限制
```nginx
# 添加到 http 块
limit_conn_zone $binary_remote_addr zone=addr:10m;
limit_conn addr 10;  # 每个 IP 最多 10 个并发连接
```
**优先级：** ⭐⭐⭐  
**作用：** 防止单个 IP 占用过多连接  
**位置：** `nginx.conf` HTTP 块

### 🔧 2. SSL/TLS 增强

#### 2.1 SSL Session 配置
```nginx
# 添加到 http 块
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 提高 SSL 性能，禁用不安全的 session tickets  
**位置：** `nginx.conf` HTTP 块

#### 2.2 OCSP Stapling
```nginx
# 添加到 server 块
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /path/to/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```
**优先级：** ⭐⭐⭐  
**作用：** 提高 SSL 验证性能和隐私  
**位置：** `snippets/ssl.conf`

#### 2.3 SSL 密钥强度
```nginx
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/ssl/dhparam.pem;  # 生成: openssl dhparam -out dhparam.pem 4096
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 增强密钥交换安全性  
**位置：** `snippets/ssl.conf`

### 🔧 3. 安全响应头增强

#### 3.1 Content Security Policy (CSP)
```nginx
# 根据实际需求调整
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'self';" always;
```
**优先级：** ⭐⭐⭐⭐⭐  
**作用：** 防止 XSS、数据注入等攻击  
**位置：** `snippets/security-headers.conf`  
**注意：** 需要根据应用需求定制

#### 3.2 增强的 Referrer Policy
```nginx
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```
**优先级：** ⭐⭐⭐  
**作用：** 控制 Referrer 信息泄露  
**位置：** `snippets/security-headers.conf`

#### 3.3 Feature Policy / Permissions Policy
```nginx
add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()" always;
```
**优先级：** ⭐⭐⭐  
**作用：** 限制浏览器功能访问  
**位置：** `snippets/security-headers.conf`

### 🔧 4. 日志安全

#### 4.1 敏感信息过滤
```nginx
# 创建 snippets/log-filters.conf
map $request_uri $loggable {
    default 1;
    ~*\.(jpg|jpeg|gif|png|ico|css|js|woff|woff2)$ 0;  # 不记录静态资源
    ~*/health 0;  # 不记录健康检查
}

# 在 server 块中使用
access_log /var/log/nginx/access.log combined if=$loggable;
```
**优先级：** ⭐⭐  
**作用：** 减少日志量，避免记录敏感信息  
**位置：** 新建 `snippets/log-filters.conf`

#### 4.2 日志轮转配置
```nginx
# logrotate 配置（系统级别）
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```
**优先级：** ⭐⭐⭐  
**作用：** 防止日志文件过大  
**位置：** `/etc/logrotate.d/nginx`

### 🔧 5. 地理位置限制

#### 5.1 GeoIP 配置
```nginx
# 需要 ngx_http_geoip_module
http {
    geoip_country /usr/share/GeoIP/GeoIP.dat;
    
    map $geoip_country_code $allowed_country {
        default no;
        CN yes;
        US yes;
        JP yes;
        # 添加允许的国家
    }
}

server {
    if ($allowed_country = no) {
        return 403;
    }
}
```
**优先级：** ⭐⭐  
**作用：** 限制特定国家/地区访问  
**位置：** `nginx.conf` HTTP 块  
**注意：** 需要安装 GeoIP 模块

---

## 高级安全配置

### 🔒 1. Web Application Firewall (WAF)

#### 1.1 ModSecurity 集成
```nginx
# 需要编译 ModSecurity 模块
load_module modules/ngx_http_modsecurity_module.so;

http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;
}
```
**优先级：** ⭐⭐⭐⭐⭐  
**作用：** 提供完整的 WAF 功能  
**推荐规则集：** OWASP ModSecurity Core Rule Set (CRS)

#### 1.2 Naxsi WAF
```nginx
# 轻量级 WAF 替代方案
http {
    include /etc/nginx/naxsi_core.rules;
}

server {
    location / {
        include /etc/nginx/naxsi.rules;
    }
}
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 轻量级 SQL 注入和 XSS 防护

### 🔒 2. 访问控制增强

#### 2.1 白名单 IP 访问
```nginx
# 创建 snippets/ip-whitelist.conf
geo $ip_whitelist {
    default 0;
    192.168.1.0/24 1;
    10.0.0.0/8 1;
    # 添加信任的 IP 段
}

# 在需要保护的 location 中使用
location /admin {
    if ($ip_whitelist = 0) {
        return 403;
    }
}
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 限制敏感路径只能从特定 IP 访问

#### 2.2 动态黑名单
```nginx
# 需要配合外部脚本使用
geo $blacklist {
    default 0;
    include /etc/nginx/blacklist.conf;  # 动态更新的黑名单文件
}

server {
    if ($blacklist) {
        return 403;
    }
}
```
**优先级：** ⭐⭐⭐  
**作用：** 动态屏蔽恶意 IP

### 🔒 3. 反向代理安全

#### 3.1 后端健康检查
```nginx
upstream backend {
    server backend1:8080 max_fails=3 fail_timeout=30s;
    server backend2:8080 max_fails=3 fail_timeout=30s;
    
    keepalive 32;
}
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 自动隔离故障后端

#### 3.2 代理超时配置
```nginx
location / {
    proxy_pass http://backend;
    
    proxy_connect_timeout 5s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # 防止响应头过大
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
}
```
**优先级：** ⭐⭐⭐  
**作用：** 防止超时攻击和资源耗尽

#### 3.3 隐藏后端错误信息
```nginx
proxy_intercept_errors on;
error_page 500 502 503 504 /error-pages/$status;
```
**优先级：** ⭐⭐⭐⭐  
**作用：** 不暴露后端错误细节

### 🔒 4. 防爬虫增强

#### 4.1 Robots.txt 配置
```nginx
location = /robots.txt {
    add_header Content-Type text/plain;
    return 200 "User-agent: *\nDisallow: /admin/\nDisallow: /api/internal/\n";
}
```
**优先级：** ⭐⭐  
**作用：** 引导爬虫行为

#### 4.2 爬虫速率限制
```nginx
# 为爬虫设置更严格的限流
map $http_user_agent $limit_bot {
    default "";
    ~*(bot|crawler|spider) $binary_remote_addr;
}

limit_req_zone $limit_bot zone=bots:10m rate=1r/s;

location / {
    limit_req zone=bots burst=5;
}
```
**优先级：** ⭐⭐⭐  
**作用：** 限制爬虫访问频率

---

## 监控和日志

### 📊 1. 安全监控

#### 1.1 实时攻击监控
```bash
# 创建监控脚本 /usr/local/bin/nginx-security-monitor.sh
#!/bin/bash

# 监控 403/404 异常增长
tail -f /var/log/nginx/access.log | grep -E " (403|404) " | while read line; do
    echo "[$(date)] Blocked: $line"
    # 可以集成到告警系统
done
```
**优先级：** ⭐⭐⭐⭐

#### 1.2 日志分析
```bash
# 统计被拦截的请求
cat /var/log/nginx/access.log | grep " 403 " | awk '{print $1}' | sort | uniq -c | sort -rn | head -20

# 统计恶意 User-Agent
cat /var/log/nginx/access.log | grep " 403 " | grep -oP '"[^"]*"$' | sort | uniq -c | sort -rn

# 统计攻击目标
cat /var/log/nginx/access.log | grep " 404 " | awk '{print $7}' | sort | uniq -c | sort -rn | head -20
```
**优先级：** ⭐⭐⭐⭐

### 📊 2. 性能监控

#### 2.1 Nginx Stub Status
```nginx
server {
    listen 127.0.0.1:8080;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```
**优先级：** ⭐⭐⭐  
**作用：** 提供 Nginx 性能指标

#### 2.2 响应时间记录
```nginx
log_format timing '$remote_addr - $remote_user [$time_local] '
                  '"$request" $status $body_bytes_sent '
                  '"$http_referer" "$http_user_agent" '
                  'rt=$request_time uct="$upstream_connect_time" '
                  'uht="$upstream_header_time" urt="$upstream_response_time"';

access_log /var/log/nginx/timing.log timing;
```
**优先级：** ⭐⭐⭐  
**作用：** 记录详细的性能数据

---

## 性能与安全平衡

### ⚖️ 1. 缓存与安全

#### 1.1 静态资源缓存
```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    
    # 保持安全头
    include /etc/nginx/snippets/security-headers.conf;
}
```
**优先级：** ⭐⭐⭐⭐

#### 1.2 代理缓存
```nginx
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=1g inactive=60m use_temp_path=off;

location / {
    proxy_cache my_cache;
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    
    # 不缓存带认证的请求
    proxy_cache_bypass $http_authorization;
    proxy_no_cache $http_authorization;
}
```
**优先级：** ⭐⭐⭐

### ⚖️ 2. 性能优化配置

#### 2.1 连接优化
```nginx
# 已配置
worker_processes auto;
worker_connections 2048;
multi_accept on;
use epoll;
```
**状态：** ✅ 已优化

#### 2.2 文件缓存（已禁用）
```nginx
# 当前配置
open_file_cache off;

# 生产环境建议启用
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors on;
```
**优先级：** ⭐⭐⭐⭐  
**注意：** 当前因 issue 619 被禁用

---

## 合规性检查

### ✔️ 1. OWASP Top 10 防护

| 威胁 | 防护措施 | 状态 |
|------|---------|------|
| A01:2021 – 访问控制失效 | IP 白名单、认证限流 | ✅ 部分 |
| A02:2021 – 加密机制失效 | TLS 1.2+、强加密套件 | ✅ 完成 |
| A03:2021 – 注入攻击 | SQL 注入检测、输入验证 | ✅ 完成 |
| A04:2021 – 不安全设计 | 安全响应头、错误页面 | ✅ 完成 |
| A05:2021 – 安全配置错误 | server_tokens off、隐藏敏感文件 | ✅ 完成 |
| A06:2021 – 危险组件 | 及时更新 Nginx | ⚠️ 需定期检查 |
| A07:2021 – 认证失败 | 限流、账户锁定 | ✅ 部分 |
| A08:2021 – 数据完整性失败 | CSP、SRI | ⚠️ 待实施 |
| A09:2021 – 日志监控失败 | 完整日志、实时监控 | ✅ 部分 |
| A10:2021 – 服务端请求伪造 | 后端访问控制 | ⚠️ 应用层 |

### ✔️ 2. PCI DSS 合规（如适用）

- [x] 禁用不安全的协议（SSLv3, TLS 1.0, TLS 1.1）
- [x] 使用强加密算法
- [x] 实施访问控制
- [x] 记录所有访问日志
- [ ] 定期安全审计
- [ ] 渗透测试

### ✔️ 3. GDPR 合规（如适用）

- [ ] 日志中匿名化 IP 地址
- [x] 最小化数据收集
- [ ] 实施数据保留策略
- [x] 安全传输（HTTPS）

---

## 实施优先级建议

### 🔥 高优先级（立即实施）

1. **CSP 头配置** - 防止 XSS 攻击
2. **SSL Session 优化** - 提高性能和安全
3. **连接数限制** - 防止资源耗尽
4. **缓冲区限制** - 防止溢出攻击
5. **OCSP Stapling** - 提高 SSL 验证效率

### ⭐ 中优先级（计划实施）

1. **ModSecurity/Naxsi WAF** - 完整 WAF 功能
2. **IP 白名单管理后台** - 方便运维
3. **实时攻击监控** - 及时响应
4. **GeoIP 限制** - 地理位置控制
5. **日志分析自动化** - 提高效率

### 💡 低优先级（按需实施）

1. **高级缓存策略** - 性能优化
2. **动态黑名单** - 自动防御
3. **详细性能监控** - 深度分析
4. **合规性审计** - 行业要求
5. **渗透测试** - 定期评估

---

## 安全配置模板

### 📄 完整的安全 server 块示例

```nginx
server {
    listen 443 ssl http2;
    server_name example.com;
    
    # SSL 配置
    include /etc/nginx/snippets/ssl.conf;
    ssl_certificate /etc/nginx/ssl/example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/example.com.key;
    
    # 安全头
    include /etc/nginx/snippets/security-headers.conf;
    
    # 安全检查
    include /etc/nginx/snippets/security-checks.conf;
    
    # 路径过滤
    include /etc/nginx/snippets/security-filters.conf;
    
    # 错误页面
    include /etc/nginx/snippets/error-pages-location.conf;
    
    # 限流（根据需求选择）
    limit_req zone=general burst=20 nodelay;
    
    # 连接限制
    limit_conn addr 10;
    
    # 应用配置
    location / {
        proxy_pass http://backend;
        include /etc/nginx/snippets/proxy-standard.conf;
    }
    
    # 管理后台（严格限流）
    location /admin {
        limit_req zone=auth_login burst=2 nodelay;
        
        # IP 白名单（可选）
        allow 192.168.1.0/24;
        deny all;
        
        proxy_pass http://backend;
    }
}
```

---

## 测试和验证

### 🧪 1. 安全测试工具

```bash
# SSL 配置测试
testssl.sh https://your-domain.com

# 安全头测试
curl -I https://your-domain.com | grep -E "(X-Frame|X-Content|Strict-Transport)"

# 性能测试
ab -n 1000 -c 10 https://your-domain.com/

# 限流测试
for i in {1..100}; do curl https://your-domain.com/admin; done
```

### 🧪 2. 在线测试工具

- **SSL Labs**: https://www.ssllabs.com/ssltest/
- **Security Headers**: https://securityheaders.com/
- **Mozilla Observatory**: https://observatory.mozilla.org/

### 🧪 3. 定期审计清单

- [ ] 每周检查访问日志异常
- [ ] 每月更新黑名单
- [ ] 每季度进行渗透测试
- [ ] 每半年审查安全配置
- [ ] 及时应用 Nginx 安全更新

---

## 相关文档

- [安全配置详解](./SECURITY-CONFIG.md) - 已实施的安全功能说明
- [快速部署指南](./QUICK-START.md) - 快速启用安全功能
- [错误页面配置](./ERROR-PAGES-GUIDE.md) - 统一错误页面
- [Nginx 官方安全指南](https://nginx.org/en/docs/http/ngx_http_core_module.html)

---

## 更新日志

### 2025-01-11
- ✅ 创建安全配置完整清单
- ✅ 整理当前已配置的安全措施
- ✅ 提供推荐增强配置
- ✅ 添加高级安全配置建议
- ✅ 提供实施优先级指导

---

**维护提醒：**
- 定期更新本文档
- 跟踪新的安全威胁
- 测试新的防护措施
- 记录配置变更

**免责声明：**
本文档提供的配置建议基于通用最佳实践，实际部署时需要根据具体业务需求和环境进行调整。安全是一个持续的过程，需要定期审查和更新。