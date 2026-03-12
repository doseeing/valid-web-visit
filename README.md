# valid_web_visit

这个项目包含两个部分：

- 本地 `hono` API 服务：访问 `http://127.0.0.1:3000/hello` 返回 `world`
- Cloudflare Worker 前端：部署后提供一个页面，用浏览器直接检查本地 API 是否可访问

## 1. 安装依赖

```bash
npm install
```

## 2. 启动本地 Hono API

```bash
npm run api:dev
```

启动成功后，访问：

- `http://127.0.0.1:3000/hello`

你会看到：

```txt
world
```

## 3. 本地预览 Cloudflare Worker 前端

```bash
npm run worker:dev
```

本地打开 Wrangler 提供的地址后，点击检测按钮即可检查你机器上的本地 API。

## 4. 部署到 Cloudflare

先登录 Cloudflare：

```bash
npx wrangler login
```

然后部署：

```bash
npm run deploy
```

部署完成后，打开 Worker 的 URL。

## 5. 重要说明

部署到 Cloudflare 的 Worker 运行在云端，云端本身无法直接访问你电脑里的 `127.0.0.1`。本项目采用的是：

- 页面托管在 Cloudflare Worker
- 浏览器中的 JavaScript 直接访问你当前机器的本地 API

所以只要你在访问页面的同一台电脑上启动了本地 `hono` 服务，页面就能检测它是否可用。
