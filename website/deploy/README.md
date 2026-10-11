# 官网部署与证书维护

## 2026-09-23 实际部署

- `skyinstrument.cn` 和 `www.skyinstrument.cn` A 记录指向已购上海 ECS；仅新增公网 80/443，SSH 来源限制、RAM 权限和原本机资源服务不变。
- 网站备案号在阿里云备案控制台核实为 `新ICP备2026008516号-1`。网站备案不代替 APP 备案。
- 静态目录 `/srv/skyinstrument/website/current` 指向 `releases/20260923-public`；上一版为 `releases/20260923`。仅发布 client 产物，没有部署 Node 服务、源码、环境文件或应用签名材料。
- 网站使用 nginx 普通账户、只读系统与唯一绑定低端口能力。HTTP 跳 HTTPS，www 跳主域名；HTTP ACME 验证路径例外。
- 访问日志只记录 IP、时间、方法、路径、状态、字节数，不记录查询参数、Cookie、Referrer；每日轮转并配置 180 天保留，后续需持续检查磁盘容量。

## 免费证书

用户明确同意 Let's Encrypt 订户协议、免费证书和自动续期。acme.sh 3.1.6 从官方 GitHub 发布归档安装，SHA-256 为 `10e2b8a9836628b98b55961f4e986794328253ad7a3d573bffb669d564d37063`，上传后在服务器校验。不执行远程脚本管道，不购买证书，不自动升级证书工具本身。

- Let's Encrypt YE1、ECC P-256，覆盖两个域名；本次有效至 2026-12-21 22:51:11 UTC。实际续期时间由 ACME 服务端建议和客户端判断，不硬编码。
- 账户和私钥只在服务器 `/root/.skyinstrument-acme`，禁止下载或纳入仓库。nginx 使用 `/etc/skyinstrument-website/tls/current` 的副本；目录 root:nginx 0750、文件 0640。
- 安装脚本核对有效期、两个域名及公私钥匹配，目录软链接原子切换，校验后热重载网站；失败尝试回退原证书。不重启原资源服务。
- `skyinstrument-certificate.timer` 每日 04:00–05:00 随机检查，错过运行补执行。已实际执行一次，Result=success、ExecMainStatus=0；未到续期时间，因此跳过重签，不等于已验证几个月后的续期。

## 后续发布与维护

`install-first-release.sh` 仅用于全新服务器 HTTP 引导；`enable-https.sh` 仅首次启用 HTTPS。当前已完成，不能重复运行。启用时已保留旧 nginx 配置于服务器 `/var/backups/skyinstrument/website-tls-*`。

内容更新：构建、审计，把 `dist/client` 放到 `client/`、`publish-release.sh` 放到 `deploy/`，上传无秘密归档并校验 SHA-256。展开后运行 `bash deploy/publish-release.sh YYYYMMDD-name`；保留旧目录，原子换链接，验证三条 HTTPS 路径，失败回退。不改证书、DNS、签名或端口。

维护时检查 `systemctl show skyinstrument-certificate.service -p Result -p ExecMainStatus`、`systemctl list-timers skyinstrument-certificate.timer`、证书期限和 HTTPS 可用性。失败先排查 DNS/80 端口 ACME 验证或连接故障，不关闭 TLS 校验，不反复强制签发消耗 CA 额度。证书工具安全更新需检查官方版本再升级。

## 验收边界

- 本站 lint、TypeScript、生产构建、四条静态路由和资源/锚点/备案号审计通过；390px 手机宽度无横向溢出、无已加载图片失败，首屏和页脚人工看图。
- 服务器通过公网域名访问首页/隐私/致谢均 200，证书验证结果 0；80/www 跳转正常。原 127.0.0.1:8080 服务仍 staging/publicService=false。
- Mac 经 utun6 代理路由，主域名 HTTP/TLS 连接中断，www 正常 301；Mac 公网浏览器验收尚未通过。未修改用户代理或系统路由，已请用户无代理复核。服务器本机成功不代替独立网络验收。
- 08:03 补充：通过无线连接的 MatePad Mini（MLR-AL00）实测独立客户端链路。主域名正常解析为 ECS 地址；按域名（非强制 IP）执行 TLS 主机名和完整证书链校验，退出 0：首页 200，www 301 至主域名，隐私/致谢/星图图片均 200。设备命令行 OpenSSL 默认 CA 目录不存在，测试显式使用从 Let's Encrypt 官方 HTTPS 下载、指纹核验的公开 ISRG Root X1，只作为本次命令 CAfile；没有安装系统证书、关闭 TLS 校验、修改系统网络或应用。首次域名连接超时，随后重试通过；不将此结果替代平板浏览器渲染/交互验收，也不声称 Mac 故障已修复。
- 官网源码已加入官方 AppGallery App Linking 入口，目标包名为 `com.joinother.skyinstrument`；若应用市场详情页尚未公开，入口回退为搜索“星象仪”。当前线上版本仍需完成一次发布切换后才会显示，不把入口称为华为认证或推荐。

参考：[acme.sh](https://github.com/acmesh-official/acme.sh)、[AppGallery 营销工具](https://developer.huawei.com/consumer/cn/doc/app/marketing-tools-0000002211952994)。
