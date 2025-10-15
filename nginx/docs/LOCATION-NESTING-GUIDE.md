# Nginx Location 嵌套和认证配置指南

**版本：** 1.0  
**更新：** 2025-01-11  
**目的：** 解释 Nginx location 嵌套规则和正确的认证配置方法

---

## 📋 目录

- [Location 嵌套规则](#location-嵌套规则)
- [常见错误](#常见错误)
- [正确的配置方案](#正确的配置方案)
- [认证配置最佳实践](#认证配置最佳实践)
- [实际案例](#实际案例)

---

## Location 嵌套规则

### ✅ 允许的嵌套

```nginx
# 1. 精确匹配 location 可以嵌套任何类型
location = /exact {
    location ~ \.php$ {  # ✅ 允许
        # ...
    }
}

# 2. 前缀匹配 location 可以嵌套任何类型
location /prefix {
    location ~ \.php$ {  # ✅ 允许
        # ...
    }
}

# 3. 优先前缀匹配可以嵌套任何类型
location ^~ /priority {
    location ~ \.php$ {  # ✅ 允许
        # ...
    }
}

# 4. 命名 location 可以嵌套精确匹配
location @named {
    location = /exact {  # ✅ 允许
        # ...
    }
}
```

### ❌ 不允许的嵌套

```nginx
# 1. 正则匹配 location 不能嵌套正则匹配
location ~ /pattern {
    location ~ \.php$ {  # ❌ 错误！
        # 这会导致配置失败或不生效
    }
}

# 2. 正则匹配 location 不能嵌套命名 location
location ~ /pattern {
    location @named {  # ❌ 错误！
        # ...
    }
}

# 3. 命名 location 不能嵌套正则匹配
location @named {
    location ~ \.php$ {  # ❌ 错误！
        # ...
    }
}
```

### 📊 Location 匹配优先级

```
优先级（从高到低）：
1. = 精确匹配           location = /path
2. ^~ 优先前缀匹配       location ^~ /path
3. ~ 正则匹配（区分大小写）location ~ /pattern
4. ~* 正则匹配（不区分）   location ~* /pattern
5. 前缀匹配             location /path
6. / 通用匹配           location /
```

---

## 常见错误

### 错误 1：在正则 location 内嵌套正则 location

**❌ 错误配置：**
```nginx
location ~ ^/(logs|health) {
    include /etc/nginx/snippets/base-auth.conf;
    try_files $uri $uri/ /index.php?$query_string;
    
    # ❌ 这个嵌套是无效的！
    location ~ \.php$ {
        fastcgi_pass php-upstream;
    }
}
```

**问题：**
- Nginx 不允许正则 location 内嵌套正则 location
- 内层的 `location ~ \.php$` 会被忽略或导致配置错误
- PHP 请求可能不会被正确处理

**✅ 正确方案（使用命名 location）：**
```nginx
location ~ ^/(logs|health) {
    include /etc/nginx/snippets/base-auth.conf;
    try_files $uri $uri/ @protected_php;
}

location @protected_php {
    rewrite ^/(logs|health)(.*)$ /index.php?$query_string last;
}

location ~ ^/(logs|health)/.*\.php$ {
    include /etc/nginx/snippets/base-auth.conf;
    fastcgi_pass php-upstream;
}
```

---

### 错误 2：认证配置不生效

**❌ 错误配置：**
```nginx
location /admin {
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    # 嵌套 location 不会继承外层的 auth_basic
    location ~ \.php$ {
        # ❌ 这里没有认证！
        fastcgi_pass php-upstream;
    }
}
```

**问题：**
- 嵌套 location **不继承**外层的 `auth_basic` 配置
- PHP 文件可以被未认证用户直接访问
- 造成安全漏洞

**✅ 正确方案（重新声明认证）：**
```nginx
location /admin {
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    try_files $uri $uri/ /index.php?$query_string;
}

location ~ ^/admin/.*\.php$ {
    # ✅ 必须重新声明认证
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    fastcgi_pass php-upstream;
}
```

---

### 错误 3：使用 if 嵌套过深

**❌ 不推荐的配置：**
```nginx
location / {
    if ($request_uri ~ ^/(logs|health)) {
        set $need_auth 1;
    }
    
    if ($need_auth = 1) {
        if ($remote_user = "") {
            return 401;  # ❌ 嵌套 if 可能不生效
        }
    }
}
```

**问题：**
- Nginx 的 `if` 指令被称为 "if is evil"
- 嵌套 if 可能导致意外行为
- 性能较差

**✅ 正确方案（使用 map）：**
```nginx
# 在 http 块
map $request_uri $auth_type {
    default "off";
    ~^/(logs|health) "Restricted Access";
}

# 在 server 块
location / {
    auth_basic $auth_type;
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

---

## 正确的配置方案

### 方案 1：命名 Location（推荐）⭐⭐⭐⭐⭐

**适用场景：** 需要对特定路径进行认证，并且该路径下有 PHP 处理

```nginx
server {
    # 普通 PHP 处理（无需认证）
    location ~ \.php$ {
        fastcgi_pass php-upstream;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # 受保护的路径
    location ~ ^/(admin|logs|health) {
        # 启用认证
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        # 尝试访问文件，不存在则转发到命名 location
        try_files $uri $uri/ @protected_php;
    }

    # 命名 location：处理受保护路径的 PHP 请求
    location @protected_php {
        # 重写到 index.php
        rewrite ^/(admin|logs|health)(.*)$ /index.php?$query_string last;
    }

    # 处理受保护路径下的直接 PHP 文件
    location ~ ^/(admin|logs|health)/.*\.php$ {
        # 重新声明认证（必须！）
        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        fastcgi_pass php-upstream;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**优点：**
- ✅ 清晰的逻辑分离
- ✅ 避免嵌套问题
- ✅ 认证保护完整
- ✅ 易于维护和扩展

---

### 方案 2：使用 Map 变量⭐⭐⭐⭐

**适用场景：** 多个路径需要不同级别的认证

```nginx
# 在 http 块定义 map
http {
    # 根据请求路径决定是否需要认证
    map $request_uri $auth_realm {
        default "off";
        ~^/admin "Admin Area";
        ~^/(logs|health) "Monitoring Area";
    }
}

server {
    # 所有 location 都应用 map 变量
    location / {
        auth_basic $auth_realm;
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        auth_basic $auth_realm;
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        fastcgi_pass php-upstream;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**优点：**
- ✅ 集中管理认证规则
- ✅ 避免重复配置
- ✅ 灵活的认证策略
- ✅ 性能良好

---

### 方案 3：分离的 Location 块⭐⭐⭐

**适用场景：** 简单的路径认证，不需要复杂的嵌套

```nginx
server {
    # 受保护的路径（静态文件）
    location ^~ /admin {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files $uri $uri/ /index.php?$query_string;
    }

    # 受保护的 PHP 文件
    location ~ ^/admin/.*\.php$ {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/.htpasswd;
        
        fastcgi_pass php-upstream;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # 普通请求
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # 普通 PHP 处理
    location ~ \.php$ {
        fastcgi_pass php-upstream;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**优点：**
- ✅ 配置简单直观
- ✅ 适合小型站点
- ✅ 易于理解

**缺点：**
- ⚠️ 可能有重复代码
- ⚠️ 不适合复杂场景

---

## 认证配置最佳实践

### 1. Basic Auth 配置

#### 生成密码文件

```bash
# 安装 htpasswd 工具（如果没有）
apt-get install apache2-utils

# 创建密码文件（首次）
htpasswd -c /etc/nginx/auth/.htpasswd admin

# 添加更多用户（不要用 -c，会覆盖）
htpasswd /etc/nginx/auth/.htpasswd developer
htpasswd /etc/nginx/auth/.htpasswd guest

# 查看密码文件
cat /etc/nginx/auth/.htpasswd
```

#### 配置文件

```nginx
# 创建 snippets/base-auth.conf
auth_basic "Restricted Access";
auth_basic_user_file /etc/nginx/auth/.htpasswd;
```

#### 使用

```nginx
location /protected {
    include /etc/nginx/snippets/base-auth.conf;
}
```

---

### 2. 认证的继承规则

**重要：** 嵌套 location **不继承**外层的认证配置！

```nginx
# ❌ 错误示例
location /admin {
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location ~ \.php$ {
        # 这里没有认证！
        fastcgi_pass php-upstream;
    }
}

# ✅ 正确示例
location /admin {
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
}

location ~ ^/admin/.*\.php$ {
    # 必须重新声明
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
    fastcgi_pass php-upstream;
}
```

---

### 3. 组合认证（Basic Auth + IP 白名单）

```nginx
# 方法 1：使用 satisfy 指令
location /admin {
    # 满足任一条件即可访问
    satisfy any;
    
    # IP 白名单
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;
    
    # Basic Auth（IP 不在白名单时需要）
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
}

# 方法 2：使用 satisfy all（两者都需要）
location /super-admin {
    # 必须同时满足两个条件
    satisfy all;
    
    # IP 白名单
    allow 192.168.1.100;
    deny all;
    
    # 并且需要认证
    auth_basic "Super Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

---

### 4. 基于时间的访问控制

```nginx
# 在 http 块定义 map
map $time_iso8601 $is_work_hours {
    default 0;
    ~T(09|1[0-7]) 1;  # 09:00 - 17:59
}

map $date_gmt $is_weekday {
    default 1;
    ~^Sat 0;
    ~^Sun 0;
}

# 在 location 使用
location /admin {
    # 工作日和工作时间才允许访问
    if ($is_work_hours = 0) {
        return 403 "Access only during work hours (9AM-6PM)";
    }
    if ($is_weekday = 0) {
        return 403 "Access only on weekdays";
    }
    
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

---

## 实际案例

### 案例 1：Laravel 应用的认证配置

**需求：**
- `/admin` 路径需要 Basic Auth
- 所有请求通过 `index.php` 处理
- 静态资源不需要认证

**配置：**
```nginx
server {
    listen 443 ssl;
    server_name example.com;
    root /var/www/laravel/public;
    index index.php;

    # 普通请求
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # 受保护的路径
    location ~ ^/admin {
        auth_basic "Admin Panel";
        auth_basic_user_file /etc/nginx/.htpasswd;
        try_files $uri $uri/ @admin_php;
    }

    # 命名 location：处理 admin 的 PHP 请求
    location @admin_php {
        rewrite ^/admin(.*)$ /index.php?$query_string last;
    }

    # 普通 PHP 处理
    location ~ ^/index\.php$ {
        fastcgi_pass php-fpm;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # 静态资源（无需认证）
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        access_log off;
    }
}
```

---

### 案例 2：多级认证系统

**需求：**
- `/public` - 无需认证
- `/user` - Basic Auth（普通用户）
- `/admin` - Basic Auth（管理员，不同的密码文件）
- `/super-admin` - Basic Auth + IP 白名单

**配置：**
```nginx
# 在 http 块定义 map
http {
    map $request_uri $auth_config {
        default "none";
        ~^/user "user";
        ~^/admin "admin";
        ~^/super-admin "super";
    }
}

server {
    listen 443 ssl;
    server_name example.com;
    root /var/www/html;

    # 公共路径
    location /public {
        # 无需认证
        try_files $uri $uri/ =404;
    }

    # 用户区域
    location /user {
        auth_basic "User Area";
        auth_basic_user_file /etc/nginx/auth/users.htpasswd;
        try_files $uri $uri/ /index.php?$query_string;
    }

    # 管理区域
    location /admin {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/auth/admins.htpasswd;
        try_files $uri $uri/ /index.php?$query_string;
    }

    # 超级管理员区域
    location /super-admin {
        satisfy all;
        
        # IP 白名单
        allow 192.168.1.100;
        deny all;
        
        # 超级管理员认证
        auth_basic "Super Admin Area";
        auth_basic_user_file /etc/nginx/auth/superadmins.htpasswd;
        
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP 处理（需要根据路径应用不同认证）
    location ~ ^/user/.*\.php$ {
        auth_basic "User Area";
        auth_basic_user_file /etc/nginx/auth/users.htpasswd;
        fastcgi_pass php-fpm;
        include fastcgi_params;
    }

    location ~ ^/admin/.*\.php$ {
        auth_basic "Admin Area";
        auth_basic_user_file /etc/nginx/auth/admins.htpasswd;
        fastcgi_pass php-fpm;
        include fastcgi_params;
    }

    location ~ ^/super-admin/.*\.php$ {
        satisfy all;
        allow 192.168.1.100;
        deny all;
        
        auth_basic "Super Admin Area";
        auth_basic_user_file /etc/nginx/auth/superadmins.htpasswd;
        fastcgi_pass php-fpm;
        include fastcgi_params;
    }
}
```

---

### 案例 3：API 端点的认证

**需求：**
- REST API 使用 Bearer Token 认证
- 特定管理 API 需要 Basic Auth 作为额外保护
- 公共 API 无需认证

**配置：**
```nginx
server {
    listen 443 ssl;
    server_name api.example.com;

    # 公共 API（无需认证）
    location /api/v1/public {
        proxy_pass http://backend;
        include /etc/nginx/snippets/proxy-headers.conf;
    }

    # 需要 Bearer Token 的 API（应用层验证）
    location /api/v1 {
        # Token 验证由后端处理
        proxy_pass http://backend;
        include /etc/nginx/snippets/proxy-headers.conf;
    }

    # 管理 API（Basic Auth + Bearer Token）
    location /api/v1/admin {
        # Nginx 层的 Basic Auth
        auth_basic "Admin API";
        auth_basic_user_file /etc/nginx/auth/.htpasswd;
        
        # 后端还会验证 Bearer Token
        proxy_pass http://backend;
        include /etc/nginx/snippets/proxy-headers.conf;
    }
}
```

---

## 测试和验证

### 测试 Basic Auth

```bash
# 无认证访问（应该返回 401）
curl -I https://example.com/admin

# 使用 Basic Auth
curl -u username:password https://example.com/admin

# 查看认证头
curl -u username:password -v https://example.com/admin 2>&1 | grep Authorization
```

### 测试嵌套 location

```bash
# 测试静态文件访问
curl -u admin:pass https://example.com/admin/style.css

# 测试 PHP 文件访问
curl -u admin:pass https://example.com/admin/dashboard.php

# 测试路由访问（通过 index.php）
curl -u admin:pass https://example.com/admin/users
```

### 检查日志

```bash
# 查看认证失败的请求
docker compose logs nginx | grep "401"

# 查看认证成功的请求
docker compose logs nginx | grep "admin@"
```

---

## 常见问题

### Q1: 为什么嵌套 location 的认证不生效？

**A:** Nginx 的嵌套 location **不继承**外层的 `auth_basic` 配置。必须在每个需要认证的 location 中重新声明。

```nginx
# ❌ 错误
location /admin {
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    location ~ \.php$ {
        # 没有认证！
    }
}

# ✅ 正确
location ~ ^/admin/.*\.php$ {
    auth_basic "Admin";
    auth_basic_user_file /etc/nginx/.htpasswd;
    # ...
}
```

### Q2: 正则 location 可以嵌套吗？

**A:** 不可以。正则 location (`~` 或 `~*`) 不能嵌套正则 location。使用命名 location (`@name`) 或分离的 location 块。

### Q3: 如何避免重复的认证配置？

**A:** 使用以下方法：
1. 将认证配置放在单独的文件中，使用 `include`
2. 使用 `map` 变量实现条件认证
3. 创建共享的 snippet 文件

### Q4: Basic Auth 安全吗？

**A:** Basic Auth 的安全性取决于：
- ✅ **必须使用 HTTPS**（否则密码明文传输）
- ✅ 使用强密码
- ✅ 定期更换密码
- ✅ 结合 IP 白名单更安全
- ⚠️ 不适合高安全要求的场景（考虑 OAuth2、JWT）

### Q5: 如何禁用浏览器的密码保存？

**A:** Basic Auth 无法阻止浏览器保存密码。如需更多控制，考虑使用：
- 基于表单的认证
- OAuth2 / OpenID Connect
- JWT Token 认证
- Authelia 等认证代理

---

## 相关文档

- [Nginx 官方文档 - Location](http://nginx.org/en/docs/http/ngx_http_core_module.html#location)
- [Nginx 官方文档 - Auth Basic](http://nginx.org/en/docs/http/ngx_http_auth_basic_module.html)
- [安全配置指南](./SECURITY-CONFIG.md)
- [快速参考](./SECURITY-QUICK-REFERENCE.md)

---

## 更新日志

### 2025-01-11
- ✅ 创建文档
- ✅ 说明 location 嵌套规则
- ✅ 提供正确的认证配置方案
- ✅ 添加实际案例
- ✅ 修正 default.conf 配置

---

**最后更新：** 2025-01-11  
**维护者：** DevOps Team  
**版本：** 1.0


用户访问 https://jso.lol/logs
           ↓
需要 Basic Auth 认证
           ↓
输入用户名和密码
           ↓
认证通过 ✓
           ↓
┌─────────────────────────────────┐
│  尝试访问静态文件                  │
│  try_files $uri $uri/           │
└─────────────────────────────────┘
           │
           │ 文件不存在
           ↓
┌─────────────────────────────────┐
│  转发到命名 location            │
│  @protected_php                 │
└─────────────────────────────────┘
           ↓
┌─────────────────────────────────┐
│  重写到 index.php               │
│  /logs → /index.php?...         │
└─────────────────────────────────┘
           ↓
     Laravel 处理请求
