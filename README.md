# valid_web_visit

这个项目包含两个部分：

- 本地 `hono` API 服务：提供 `/hello` 和 `/files` 两个接口
- Cloudflare Worker 前端：部署后提供一个页面，用浏览器直接检查本地 API 是否可访问，并查看 `/files` 返回结果
- macOS 状态栏 App：负责启动本地 `hono` API，并在菜单栏显示运行状态

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
- `http://127.0.0.1:3000/files`

你会看到：

```txt
world
```

以及类似这样的 JSON：

```json
{
  "path": "/Users/your-name/Desktop",
  "count": 2,
  "files": [
    { "name": "demo.txt", "type": "file" },
    { "name": "screenshots", "type": "directory" }
  ]
}
```

## 3. 本地预览 Cloudflare Worker 前端

```bash
npm run worker:dev
```

本地打开 Wrangler 提供的地址后，可以：

- 点击“检测 /hello”确认本地接口是否返回 `world`
- 点击“读取 /files”查看当前用户桌面下的文件列表

## 4. 运行前端测试

```bash
npm test
```

## 5. 部署到 Cloudflare

先登录 Cloudflare：

```bash
npx wrangler login
```

然后部署：

```bash
npm run deploy
```

部署完成后，打开 Worker 的 URL。

## 6. 运行 macOS 状态栏 App

状态栏应用位于 [macos-status-app/Package.swift](/Users/weiyao/github/valid_web_visit/macos-status-app/Package.swift)。

可以直接用 Xcode 打开这个 Swift Package，或者在终端里执行：

```bash
cd macos-status-app
swift run
```

启动后它会：

- 自动运行仓库根目录下的 `api/server.js`
- 在菜单栏显示 `Hono On`、`Hono Off`、`Hono ...` 或 `Hono Err`
- 在菜单里提供 `Start/Stop`、打开 `/hello`、打开 `/files` 和最近日志

## 7. 重要说明

部署到 Cloudflare 的 Worker 运行在云端，云端本身无法直接访问你电脑里的 `127.0.0.1`。本项目采用的是：

- 页面托管在 Cloudflare Worker
- 浏览器中的 JavaScript 直接访问你当前机器的本地 API

所以只要你在访问页面的同一台电脑上启动了本地 `hono` 服务，页面就能检测它是否可用。
