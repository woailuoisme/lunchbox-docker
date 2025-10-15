# Nginx 安全配置指南

本文档说明如何使用和配置 Nginx 的安全防护功能。

## 📋 目录

- [配置文件说明](#配置文件说明)
- [安全功能列表](#安全功能列表)
- [使用方法](#使用方法)
- [测试验证](#测试验证)
- [自定义配置](#自定义配置)
- [常见问题](#常见问题)

---

## 配置文件说明

### 核心配置文件

1. **`snippets/security-maps.conf`**
   - 位置：HTTP 块级别
   - 功能：定义安全检测 Map 变量
   - 用途：检测恶意 User-Agent、SQL 注入、路径遍历等

2. **`snippets/security-checks.conf`**
   - 位置：Server 块级别
   - 功能：应用安全检测规则
   - 用途：根据 Map 变量阻止恶意请求

3. **`snippets/security-filters.conf`**
   - 位置：Server 块级别
   - 功能：Location 级别的路径过滤
   - 用途：屏蔽敏感文件和目录访问

4. **`snippets/security-headers.conf`**
   - 位置：Server 块级别
   - 功能：添加安全响应头
   - 用途：提升浏览器安全性

---

## 安全功能列表

### ✅ 1. 敏感文件保护

屏蔽以下文件和目录的访问：

- **隐藏文件**: `.env`, `.git`, `.svn`, `.htaccess`, `.DS_Store`
- **配置文件**: `*.ini`, `*.conf`, `*.yml`, `*.yaml`, `*.toml`
- **备份文件**: `*.bak`, `*.backup`, `*.old`, `*.tmp`
- **数据库文件**: `*.sql`, `*.sqlite`, `*.db`
- **源代码**: `*.py`, `*.rb`, `*.pl`, `*.sh`, `*.java`

### ✅ 2. 开发工具保护

屏蔽开发相关目录和文件：

- **依赖目录**: `vendor/`, `node_modules/`, `bower_components/`
- **包管理**: `composer.json`, `package.json`, `yarn.lock`
- **容器配置**: `Dockerfile`, `docker-compose.yml`
- **CI/CD**: `.github/`, `.gitlab-ci.yml`, `.travis.yml`

### ✅ 3. 后台管理保护

屏蔽常见后台管理路径：

- **phpMyAdmin**: `/phpmyadmin`, `/pma`, `/adminer`
- **WordPress**: `/wp-admin`, `/wp-login.php`, `/xmlrpc.php`
- **其他后台**: `/console`, `/actuator`, `/jolokia`

### ✅ 4. 恶意请求检测

检测并阻止以下恶意行为：

#### User-Agent 检测
- 扫描工具: `sqlmap`, `nikto`, `nmap`, `masscan`, `burp`
- 空 User-Agent
- 自动化工具: `wget`, `curl`, `python-requests`

#### SQL 注入检测
- `union select`
- `insert into`
- `delete from`
- `drop table`
- `exec()`, `eval()`

#### 路径遍历检测
- `../../`
- `../etc/passwd`
- `proc/self/environ`

#### HTTP 方法限制
只允许: `GET`, `POST`, `HEAD`, `PUT`, `DELETE`, `OPTIONS`, `PATCH`

### ✅ 5. 安全响应头

自动添加以下安全头：

```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

---

## 使用方法

### 在新站点中启用安全配置

编辑站点配置文件（例如 `sites/example.conf`）：

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    # 引入 SSL 配置
    include /etc/nginx/snippets/ssl.conf;

    # 引入安全配置（推荐顺序）
    include /etc/nginx/snippets/security-headers.conf;
    include /etc/nginx/snippets/security-checks.conf;
    include /etc/nginx/snippets/security-filters.conf;

    # 其他配置...
    location / {
        proxy_pass http://backend;
    }
}
```

### 配置说明

1. **security-headers.conf**: 必须在最前面，确保所有响应都包含安全头
2. **security-checks.conf**: 在处理请求前先检测恶意行为
3. **security-filters.conf**: 最后过滤特定路径访问

---

## 测试验证

### 1. 测试敏感文件保护

```bash
# 应该返回 404
curl -I https://your-domain.com/.env
curl -I https://your-domain.com/.git/config
curl -I https://your-domain.com/composer.json
curl -I https://your-domain.com/.htaccess
```

预期结果：`404 Not Found`，且不记录到日志

### 2. 测试恶意 User-Agent 阻止

```bash
# 应该返回 403
curl -I https://your-domain.com/ -A "sqlmap/1.0"
curl -I https://your-domain.com/ -A "nikto"
curl -I https://your-domain.com/ -A ""
```

预期结果：`403 Forbidden`

### 3. 测试 SQL 注入防护

```bash
# 应该返回 403
curl -I "https://your-domain.com/?id=1' union select * from users--"
curl -I "https://your-domain.com/?id=1; drop table users"
```

预期结果：`403 Forbidden`

### 4. 测试路径遍历防护

```bash
# 应该返回 403
curl -I "https://your-domain.com/../../../../etc/passwd"
curl -I "https://your-domain.com/../../../etc/shadow"
```

预期结果：`403 Forbidden`

### 5. 测试无效 HTTP 方法

```bash
# 应该返回 405
curl -X TRACE https://your-domain.com/
curl -X CONNECT https://your-domain.com/
```

预期结果：`405 Method Not Allowed`

### 6. 检查安全响应头

```bash
curl -I https://your-domain.com/ | grep -E "(Strict-Transport|X-Frame|X-Content|X-XSS)"
```

预期结果：应该看到所有安全头

---

## 自定义配置

### 允许特定 User-Agent

如果需要允许某些被屏蔽的 User-Agent（如 `curl` 用于监控），编辑 `security-maps.conf`：

```nginx
map $http_user_agent $bad_user_agent {
    default 0;

    # 注释掉不想屏蔽的
    # ~*curl 1;
    # ~*wget 1;

    ~*sqlmap 1;
    ~*nikto 1;
    # ... 其他规则
}
```

### 允许特定路径访问

如果某些路径被误屏蔽，在站点配置中添加例外：

```nginx
server {
    # ... 其他配置

    # 在 security-filters.conf 之前添加例外
    location = /composer.json {
        # 允许访问此文件
        try_files $uri =404;
    }

    # 然后引入安全过滤
    include /etc/nginx/snippets/security-filters.conf;
}
```

### 临时禁用某个安全功能

在站点配置中注释掉对应的 include：

```nginx
server {
    include /etc/nginx/snippets/security-headers.conf;
    # include /etc/nginx/snippets/security-checks.conf;  # 临时禁用
    include /etc/nginx/snippets/security-filters.conf;
}
```

### 调整 SQL 注入规则严格度

编辑 `security-maps.conf`，调整正则表达式：

```nginx
map $query_string $bad_sql_injection {
    default 0;

    # 只检测最危险的注入
    ~*union.*select 1;
    ~*drop.*table 1;

    # 注释掉可能误报的规则
    # ~*select.*from 1;
    # ~*update.*set 1;
}
```

---

## 常见问题

### Q1: 为什么我的正常请求被屏蔽了？

**可能原因：**
1. User-Agent 包含被屏蔽的关键词（如 `curl`, `python`）
2. URL 参数包含 SQL 关键词（如正常的搜索功能）
3. 访问的路径恰好匹配过滤规则

**解决方法：**
- 检查日志确认被哪个规则拦截
- 在站点配置中添加例外规则
- 调整 `security-maps.conf` 或 `security-filters.conf`

### Q2: 如何查看被屏蔽的请求？

恶意请求默认不记录日志（`access_log off`），如需调试：

1. 临时启用日志：编辑对应配置文件，注释掉 `access_log off;`
2. 重载 Nginx：`docker compose exec nginx nginx -s reload`
3. 查看日志：`docker compose logs nginx | grep 403`

### Q3: 安全配置会影响性能吗？

影响很小：
- Map 变量查找是 O(1) 操作
- Location 匹配使用高效的正则引擎
- 大部分恶意请求在早期就被拦截，减少后端负载

### Q4: 如何更新安全规则？

1. 编辑对应的配置文件
2. 测试配置：`docker compose exec nginx nginx -t`
3. 重载配置：`docker compose exec nginx nginx -s reload`

### Q5: 这些规则能防止所有攻击吗？

**不能**。这只是基础防护层，建议配合：
- Web 应用防火墙（WAF）
- 定期安全审计
- 及时更新软件补丁
- 应用层输入验证
- 数据库访问权限控制

---

## 日志分析

### 查看被拦截的恶意请求

```bash
# 查看 403 错误（被安全规则拦截）
docker compose logs nginx | grep " 403 "

# 查看 404 错误（敏感文件访问）
docker compose logs nginx | grep " 404 " | grep -E "(\.env|\.git|composer\.json)"

# 查看 405 错误（无效 HTTP 方法）
docker compose logs nginx | grep " 405 "
```

### 识别攻击模式

```bash
# 统计最常见的攻击路径
docker compose logs nginx | grep " 404 " | awk '{print $7}' | sort | uniq -c | sort -rn | head -20

# 统计攻击来源 IP
docker compose logs nginx | grep " 403 " | awk '{print $1}' | sort | uniq -c | sort -rn | head -20

# 识别恶意 User-Agent
docker compose logs nginx | grep " 403 " | grep -oP '"[^"]*"$' | sort | uniq -c | sort -rn
```

---

## 维护建议

### 定期检查

- **每周**：查看日志，识别新的攻击模式
- **每月**：更新安全规则，添加新的威胁特征
- **每季度**：进行安全测试，验证防护效果

### 安全规则来源

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Nginx 官方安全指南](https://nginx.org/en/docs/http/ngx_http_core_module.html#satisfy)
- [Common Web Attack Patterns](https://github.com/0xInfection/Awesome-WAF)

### 监控告警

建议配置告警规则：
- 短时间内大量 403/404 错误
- 来自同一 IP 的频繁恶意请求
- 新出现的攻击 User-Agent

---

## 相关文档

- [Nginx 主配置](../nginx.conf)
- [限流配置](../nginx.conf#L88-100) - Rate Limiting
- [SSL 配置](../snippets/ssl.conf)
- [错误页面配置](../snippets/error-pages.conf)

---

## 更新日志

### 2025-01-11
- ✅ 创建初始安全配置
- ✅ 添加敏感文件保护
- ✅ 添加恶意 User-Agent 检测
- ✅ 添加 SQL 注入防护
- ✅ 添加路径遍历防护
- ✅ 添加 HTTP 方法限制

---

## 贡献

如果发现新的攻击模式或有改进建议，欢迎：
1. 提交 Issue
2. 创建 Pull Request
3. 更新此文档

---

**⚠️ 重要提示**：
- 在生产环境部署前，务必先在测试环境验证
- 根据实际业务需求调整规则，避免误伤正常用户
- 定期审查和更新安全规则
- 安全配置只是防御的一部分，不能替代其他安全措施
