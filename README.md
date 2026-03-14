# localbridge

这个项目包含几个部分：

- 本地 `hono` API 服务：提供 `/hello` 和 `/files` 两个接口
- 本地 Go API 服务：提供和 `hono` 服务一致的 `/`、`/hello` 和 `/files` 接口
- Cloudflare Worker 前端：部署后提供一个页面，用浏览器直接检查本地 API 是否可访问，并查看 `/files` 返回结果
- macOS 状态栏 App：负责启动本地 `hono` API，并在菜单栏显示运行状态

## 1. 安装依赖

```bash
npm install
```

## 2. 启动本地 Local Bridge API

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

## 3. 启动本地 Go API

```bash
npm run api:go
```

它默认监听 `http://127.0.0.1:3000`，接口行为和现有 JS 版本一致：

- `GET /`
- `GET /hello`
- `GET /files`

如果需要改端口，也可以这样启动：

```bash
cd go-api
PORT=3001 go run -ldflags=-linkmode=external .
```

如果你想生成可直接运行的 Go 二进制：

```bash
npm run api:go:package
```

默认产物会放在 `go-api/dist/`，文件名类似：

```text
go-api/dist/go-api-darwin-arm64
```

在 macOS 上，打包脚本会使用外部链接模式生成可执行文件，避免新系统上因缺少 `LC_UUID` 导致二进制无法启动。

也可以通过环境变量指定目标平台，例如：

```bash
GOOS=linux GOARCH=amd64 npm run api:go:package
```

## 4. 本地预览 Cloudflare Worker 前端

```bash
npm run worker:dev
```

本地打开 Wrangler 提供的地址后，可以：

- 点击“检测 /hello”确认本地接口是否返回 `world`
- 点击“读取 /files”查看当前用户桌面下的文件列表

## 5. 运行前端测试

```bash
npm test
```

## 6. 部署到 Cloudflare

先登录 Cloudflare：

```bash
npx wrangler login
```

然后部署：

```bash
npm run deploy
```

部署完成后，打开 Worker 的 URL。

## 7. 运行 macOS 状态栏 App

状态栏应用位于 `macos-status-app/Package.swift`。

可以直接用 Xcode 打开这个 Swift Package，或者在终端里执行：

```bash
npm run macos:dev
```

启动后它会：

- 优先使用 App 内置的 Go API 二进制
- 开发态下会使用系统里的 `go` 直接运行 `go-api`
- 打包后的正式版默认打开 [localbridge.awayyao.workers.dev](https://localbridge.awayyao.workers.dev/)，开发态默认打开本地 `http://127.0.0.1:8787`
- 在菜单栏显示 `Bridge On`、`Bridge Off`、`Bridge ...` 或 `Bridge Err`
- 在菜单里提供 `Start/Stop`、打开 `/hello`、打开 `/files` 和最近日志

如果你想把运行时一起打进 `.app`，可以在仓库根目录执行：

```bash
npm run macos:package
```

这个命令会生成：

```text
macos-status-app/dist/LocalBridge.app
```

直接运行下面这个命令时，会先重新打包，再打开最新的 `.app`：

```bash
npm run macos:run
```

打包时会把这些内容一起塞进 App：

- Go API 可执行文件
- macOS 状态栏应用主程序

前提是你的机器上已经装好 `go`，这样打包脚本才能先把 Go API 编译出来再塞进 `.app`。

## 8. 重要说明

部署到 Cloudflare 的 Worker 运行在云端，云端本身无法直接访问你电脑里的 `127.0.0.1`。本项目采用的是：

- 页面托管在 Cloudflare Worker
- 浏览器中的 JavaScript 直接访问你当前机器的本地 API

所以只要你在访问页面的同一台电脑上启动了本地 `hono` 服务，页面就能检测它是否可用。
