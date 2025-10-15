# Nginx 安全配置 - 快速部署指南

## 🚀 快速开始

### 1. 已完成的配置

所有安全配置已经就绪，无需额外配置即可使用：

✅ **已启用的安全功能：**
- 敏感文件保护（.env, .git, .htaccess 等）
- 恶意 User-Agent 检测和拦截
- SQL 注入防护
- 路径遍历攻击防护
- HTTP 方法限制
- 开发文件和目录保护
- 安全响应头自动添加

### 2. 重启 Nginx 应用配置

```bash
# 进入项目目录
cd /Users/seaside/Projects/docker/local

# 测试配置文件语法
docker compose exec nginx nginx -t

# 重载 Nginx 配置（推荐，不中断服务）
docker compose exec nginx nginx -s reload

# 或者重启容器（如果重载失败）
docker compose restart nginx
```

### 3. 验证配置是否生效

```bash
# 运行自动化测试脚本
./nginx/test-security.sh https://your-domain.com

# 或者手动测试几个关键点
curl -I https://your-domain.com/.env          # 应返回 404
curl -I https://your-domain.com/ -A "sqlmap"  # 应返回 403
curl -I https://your-domain.com/              # 应返回 200
```

### 4. 查看拦截日志

```bash
# 查看最近被拦截的请求
docker compose logs nginx --tail=100 | grep -E " (403|404) "

# 实时监控
docker compose logs -f nginx | grep -E " (403|404) "
```

---

## 📋 配置文件说明

### 自动生效的配置

这些配置已在 `nginx.conf` 的默认 server 块中启用：

```nginx
# 位置：nginx.conf 的 default_server 块
include /etc/nginx/snippets/security-maps.conf;      # Map 变量定义
include /etc/nginx/snippets/security-headers.conf;   # 安全响应头
include /etc/nginx/snippets/security-checks.conf;    # 恶意请求检测
include /etc/nginx/snippets/security-filters.conf;   # 路径过滤
```

### 在其他站点中启用（可选）

如果要在特定站点配置中使用，编辑 `sites/*.conf`：

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    # 添加以下三行
    include /etc/nginx/snippets/security-headers.conf;
    include /etc/nginx/snippets/security-checks.conf;
    include /etc/nginx/snippets/security-filters.conf;

    # 其他配置...
}
```

---

## 🛡️ 主要防护功能

### 1. 敏感文件拦截（返回 404）
- `.env`, `.git`, `.svn`, `.htaccess`
- `composer.json`, `package.json`
- `Dockerfile`, `docker-compose.yml`
- `*.bak`, `*.backup`, `*.old`, `*.sql`

### 2. 恶意请求拦截（返回 403）
- 扫描工具 User-Agent: `sqlmap`, `nikto`, `nmap`, `burp`
- SQL 注入尝试: `union select`, `drop table`
- 路径遍历: `../../etc/passwd`
- 空 User-Agent

### 3. 无效 HTTP 方法（返回 405）
- 只允许: GET, POST, HEAD, PUT, DELETE, OPTIONS, PATCH
- 拒绝: TRACE, CONNECT 等

---

## 🔧 常见问题

### Q: 正常请求被拦截了怎么办？

**解决方法 1：临时允许特定路径**

在站点配置中，在 `security-filters.conf` 之前添加：

```nginx
# 允许访问 composer.json
location = /composer.json {
    try_files $uri =404;
}

# 然后引入安全过滤
include /etc/nginx/snippets/security-filters.conf;
```

**解决方法 2：修改 Map 规则**

编辑 `nginx/snippets/security-maps.conf`，注释掉相关规则：

```nginx
map $http_user_agent $bad_user_agent {
    default 0;
    
    # 允许 curl 用于监控
    # ~*curl 1;
    
    ~*sqlmap 1;
    # ...
}
```

### Q: 如何临时禁用安全功能？

编辑站点配置，注释掉对应的 include：

```nginx
server {
    # include /etc/nginx/snippets/security-checks.conf;  # 临时禁用
    include /etc/nginx/snippets/security-filters.conf;
}
```

然后重载配置：
```bash
docker compose exec nginx nginx -s reload
```

### Q: 如何查看哪些请求被拦截？

```bash
# 查看 403 错误（恶意请求）
docker compose logs nginx | grep " 403 " | tail -20

# 查看 404 错误（敏感文件访问）
docker compose logs nginx | grep " 404 " | grep -E "(\.env|\.git)" | tail -20

# 统计攻击来源 IP
docker compose logs nginx | grep " 403 " | awk '{print $1}' | sort | uniq -c | sort -rn
```

---

## 📊 测试检查清单

部署后建议进行以下测试：

- [ ] 测试正常访问：`curl -I https://your-domain.com/`
- [ ] 测试 .env 拦截：`curl -I https://your-domain.com/.env`
- [ ] 测试 .git 拦截：`curl -I https://your-domain.com/.git/config`
- [ ] 测试恶意 UA：`curl -I https://your-domain.com/ -A "sqlmap"`
- [ ] 测试 SQL 注入：`curl -I "https://your-domain.com/?id=1%20union%20select"`
- [ ] 检查安全头：`curl -I https://your-domain.com/ | grep X-Frame`

或者直接运行测试脚本：
```bash
./nginx/test-security.sh https://your-domain.com
```

---

## 📚 相关文档

- [详细安全配置说明](SECURITY-CONFIG.md) - 完整的功能说明和自定义指南
- [测试脚本](../scripts/test-security.sh) - 自动化安全测试工具
- [主配置文件](../nginx.conf) - Nginx 主配置

---

## 🔄 更新和维护

### 查看最近的攻击尝试

```bash
# 每天检查一次
docker compose logs nginx --since 24h | grep -E " (403|404) " | wc -l
```

### 定期更新规则

根据日志中的新攻击模式，更新以下文件：
- `snippets/security-maps.conf` - 添加新的恶意特征
- `snippets/security-filters.conf` - 添加新的敏感路径

### 重载配置

每次修改配置后：
```bash
# 1. 测试语法
docker compose exec nginx nginx -t

# 2. 重载配置
docker compose exec nginx nginx -s reload
```

---

## ⚠️ 重要提示

1. **首次部署前务必测试**：在生产环境启用前，先在测试环境验证
2. **备份原配置**：修改前备份原有配置文件
3. **监控误报**：部署后密切关注是否有正常请求被拦截
4. **逐步启用**：可以先在默认 server 块测试，确认无误后再扩展到其他站点
5. **保持更新**：定期查看日志，根据新的攻击模式更新规则

---

## 🆘 故障排除

### 配置测试失败

```bash
docker compose exec nginx nginx -t
```

查看错误信息，通常是语法错误或文件路径问题。

### 服务无法启动

```bash
# 查看详细日志
docker compose logs nginx --tail=50

# 检查配置文件是否存在
docker compose exec nginx ls -la /etc/nginx/snippets/
```

### 全局回滚

如果遇到严重问题，可以临时注释掉所有安全配置：

```nginx
# 编辑 nginx.conf
# include /etc/nginx/snippets/security-maps.conf;
# include /etc/nginx/snippets/security-checks.conf;
# include /etc/nginx/snippets/security-filters.conf;
```

然后重载配置并逐个调试。

---

## 📞 获取帮助

- 查看详细文档：[SECURITY-CONFIG.md](SECURITY-CONFIG.md)
- 检查 Nginx 官方文档：https://nginx.org/en/docs/
- 查看 OWASP 安全指南：https://owasp.org/

---

**最后更新：** 2025-01-11
**版本：** 1.0
**状态：** ✅ 生产就绪