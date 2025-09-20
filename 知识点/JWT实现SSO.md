SSO的核心就是，**所有应用都信任这个中心化的认证服务器**。

主要组件：
1. **用户 (User Agent)**：通常指用户的浏览器。
    
2. **客户端应用 (Client Applications / SPs)**：需要登录才能访问的各个业务系统，例如 app-a.com, app-b.com。它们自身不处理用户密码，而是委托给认证服务器。
    
3. **认证服务器 (Authentication Server / IdP)**：整个SSO体系的核心。它负责：
    
    - 管理用户数据库（用户名、密码）。
        
    - 提供统一的登录页面。
        
    - 验证用户身份。
        
    - 生成并签发JWT。

JWT单点登录流程：
首次登陆：
1. 用户访问应用A
2. 应用A发现用户未登录（无session或cookie），重定向到认证服务器https://auth.com/login?redirect_uri=https://app-a.com/callback
3. 用户在认证服务器登陆，认证服务器签发JWT，JWT Payload包含数据、令牌过期时间等；认证服务器使用私钥对JWT进行签名。
4. 认证服务器将用户重定向到应用Ahttps://app-a.com/callback?token=eyJhbGciOiJ...
5. 应用A验证JWT并创建会话
访问应用B
6. 用户访问应用B，发现用户未登录，将用户重定向到认证服务器
7. 认证服务器发现用户已登录，签发新JWT并重定向
8. 应用B验证JWT并创建会话

单点登出 Single Log-out
登出比登录复杂，因为JWT是无状态的。
1. 用户在应用A登出：应用A清除本地会话，将用户重定向到认证服务器的登出接口auth.com/logout
2. 认证服务器处理登出：
	1. 认证服务器清除自己的中心会话，通知所有应用（后端服务间调用）；
	2. JWT黑名单，认证服务器将该JWT的ID添加到黑名单中，当应用拿着这个JWT来验证时，认证服务器告诉令牌已作废，但这破坏了JWT的无状态性。更常见的是短期Access Token + 长期Refresh Token管理会话。

 >  JWT登出
 >  方式一：前端iframe实现JWT登出：
 >  `<iframe src="https://app-a.com/slo-logout" style="display:none;"></iframe>`
 >  缺点是严重依赖第三方Cookie、某个登出端点响应缓慢会拖慢整个流程、前端暴露所有集成的应用列表
 >方式二：后端服务间调用
 >认证服务器在登出时，通过其后端服务，直接调用每一个应用预先注册好的“登出回调API”。
 >要求预先在认证服务器上注册应用的“登出回调URL”