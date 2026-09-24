# 固定局域网入口

地址：**http://go-kit.local/**，无需填写端口。

架构：Bonjour/mDNS 将 `go-kit.local` 广播为这台 Mac 的局域网 IPv4 地址；当前占用 80 端口的 `renovate-kit` Next 服务按 Host 转发到围棋应用的 `127.0.0.1:5184`。只有 `go-kit.local` 匹配这条转发，其余网站路由不变。

`scripts/start-lan.mjs` 启动围棋应用及 Bonjour 广播，每 15 秒检查局域网 IP；切换网络时先撤销旧广播再注册新地址。固定的是域名，不是路由器分配的 IP。

## 常驻服务

- LaunchAgent：`~/Library/LaunchAgents/com.percival.go-kit.plist`
- 配置源文件：`deploy/com.percival.go-kit.plist`
- 日志：`~/Library/Logs/go-kit.log`、`~/Library/Logs/go-kit-error.log`
- 登录后自动启动，进程意外退出后自动重启。
- 网页入口依赖已有的 `com.percival.renovate-kit` 服务及其域名转发配置。对应补丁保存在 `deploy/lan-route.patch`。

手动启动（不要与已启动的 LaunchAgent 同时运行）：

```sh
npm run start:lan
```

当前用户的服务管理命令：

```sh
launchctl print gui/501/com.percival.go-kit
launchctl kickstart -k gui/501/com.percival.go-kit
launchctl bootout gui/501/com.percival.go-kit
launchctl bootstrap gui/501 /Users/percival/Library/LaunchAgents/com.percival.go-kit.plist
```

设备须处于同一可互通的局域网并支持 mDNS；Mac 须保持开机、已登录且未休眠。入口使用 HTTP。没有配置公网端口转发。

原开发地址 `http://127.0.0.1:5173` 和 `http://go-kit.local` 属于不同浏览器来源，学习进度分别存储，不会自动同步。

2026-09-23 已验证：域名解析至 `192.168.0.124`，域名首页和 `/src/app.js` 均返回 HTTP 200，首页内容为围棋学堂；原 `renovate-kit.local` 仍返回 HTTP 200。LaunchAgent 处于 running 状态。未在另一台物理设备上测试。

如需撤销：停止上述 Go Kit LaunchAgent，再移除 `renovate-kit/next.config.ts` 中注释标识的 `rewrites` 配置；原文件内容没有被替换。不要停止已有的装修项目服务。
