function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

export function buildHelloResult({ ok, status, text, error, url }) {
  if (!url) {
    return {
      statusClass: 'error',
      title: '检测失败',
      body: '请输入一个有效的 API 地址。'
    }
  }

  if (error) {
    return {
      statusClass: 'error',
      title: '接口不可用',
      body: escapeHtml(error.message || '请求失败')
    }
  }

  if (ok && String(text).trim() === 'world') {
    return {
      statusClass: 'ok',
      title: '接口可用',
      body: `收到响应：<code>${escapeHtml(text)}</code>`
    }
  }

  return {
    statusClass: 'error',
    title: '接口已响应，但结果不符合预期',
    body: `HTTP ${status}，内容：<code>${escapeHtml(text || '')}</code>`
  }
}

export function buildFilesResult({ ok, status, data, error }) {
  if (error) {
    return {
      statusClass: 'error',
      title: '桌面文件读取失败',
      body: escapeHtml(error.message || '请求失败')
    }
  }

  if (!ok) {
    return {
      statusClass: 'error',
      title: '桌面文件读取失败',
      body: `HTTP ${status}`
    }
  }

  const files = Array.isArray(data?.files) ? data.files : []
  const items = files
    .map((file) => `<li><code>${escapeHtml(file.name)}</code> <span>${escapeHtml(file.type)}</span></li>`)
    .join('')

  return {
    statusClass: 'ok',
    title: `桌面文件读取成功（${files.length} 项）`,
    body: files.length > 0 ? `<ul class="file-list">${items}</ul>` : '桌面目录当前为空。'
  }
}

export const clientScript = String.raw`
function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function buildHelloResult({ ok, status, text, error, url }) {
  if (!url) {
    return {
      statusClass: 'error',
      title: '检测失败',
      body: '请输入一个有效的 API 地址。'
    }
  }

  if (error) {
    return {
      statusClass: 'error',
      title: '接口不可用',
      body: escapeHtml(error.message || '请求失败')
    }
  }

  if (ok && String(text).trim() === 'world') {
    return {
      statusClass: 'ok',
      title: '接口可用',
      body: '收到响应：<code>' + escapeHtml(text) + '</code>'
    }
  }

  return {
    statusClass: 'error',
    title: '接口已响应，但结果不符合预期',
    body: 'HTTP ' + status + '，内容：<code>' + escapeHtml(text || '') + '</code>'
  }
}

function buildFilesResult({ ok, status, data, error }) {
  if (error) {
    return {
      statusClass: 'error',
      title: '桌面文件读取失败',
      body: escapeHtml(error.message || '请求失败')
    }
  }

  if (!ok) {
    return {
      statusClass: 'error',
      title: '桌面文件读取失败',
      body: 'HTTP ' + status
    }
  }

  const files = Array.isArray(data && data.files) ? data.files : []
  const items = files
    .map((file) => '<li><code>' + escapeHtml(file.name) + '</code> <span>' + escapeHtml(file.type) + '</span></li>')
    .join('')

  return {
    statusClass: 'ok',
    title: '桌面文件读取成功（' + files.length + ' 项）',
    body: files.length > 0 ? '<ul class="file-list">' + items + '</ul>' : '桌面目录当前为空。'
  }
}

const baseInput = document.getElementById('api-base')
const helloResult = document.getElementById('hello-result')
const filesResult = document.getElementById('files-result')
const helloButton = document.getElementById('check-hello')
const filesButton = document.getElementById('check-files')

function setResult(element, result) {
  element.innerHTML = '<strong class="' + result.statusClass + '">' + result.title + '</strong><span>' + result.body + '</span>'
}

helloButton.addEventListener('click', async () => {
  const baseUrl = baseInput.value.trim().replace(/\/$/, '')
  const url = baseUrl ? baseUrl + '/hello' : ''

  setResult(helloResult, {
    statusClass: '',
    title: '检测中',
    body: '正在请求 <code>' + (url || '未提供地址') + '</code> ...'
  })

  if (!url) {
    setResult(helloResult, buildHelloResult({ url }))
    return
  }

  try {
    const response = await fetch(url)
    const text = await response.text()
    setResult(helloResult, buildHelloResult({ ok: response.ok, status: response.status, text, url }))
  } catch (error) {
    setResult(helloResult, buildHelloResult({ error, url }))
  }
})

filesButton.addEventListener('click', async () => {
  const baseUrl = baseInput.value.trim().replace(/\/$/, '')
  const url = baseUrl ? baseUrl + '/files' : ''

  setResult(filesResult, {
    statusClass: '',
    title: '读取中',
    body: '正在请求 <code>' + (url || '未提供地址') + '</code> ...'
  })

  if (!url) {
    setResult(filesResult, buildFilesResult({ error: new Error('请输入一个有效的 API 地址。') }))
    return
  }

  try {
    const response = await fetch(url)
    const data = await response.json()
    setResult(filesResult, buildFilesResult({ ok: response.ok, status: response.status, data }))
  } catch (error) {
    setResult(filesResult, buildFilesResult({ error }))
  }
})
`

export function renderPage() {
  return `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Local Hono API Checker</title>
    <style>
      :root {
        --panel: rgba(255, 252, 247, 0.86);
        --ink: #1d2433;
        --muted: #5b6271;
        --accent: #d85f3c;
        --ok: #0f7b55;
        --error: #b5352f;
        --line: rgba(29, 36, 51, 0.12);
      }

      * {
        box-sizing: border-box;
      }

      body {
        margin: 0;
        min-height: 100vh;
        font-family: "Avenir Next", "Segoe UI", sans-serif;
        color: var(--ink);
        background:
          radial-gradient(circle at top left, rgba(216, 95, 60, 0.22), transparent 32%),
          radial-gradient(circle at bottom right, rgba(21, 114, 152, 0.18), transparent 28%),
          linear-gradient(135deg, #f7e8cf, #f4f2ed 48%, #dce9ef);
        display: grid;
        place-items: center;
        padding: 24px;
      }

      .card {
        width: min(820px, 100%);
        background: var(--panel);
        border: 1px solid var(--line);
        border-radius: 28px;
        padding: 32px;
        box-shadow: 0 24px 80px rgba(42, 47, 58, 0.14);
        backdrop-filter: blur(16px);
      }

      h1 {
        margin: 0 0 12px;
        font-size: clamp(2rem, 6vw, 3.5rem);
        line-height: 0.98;
        letter-spacing: -0.04em;
      }

      p {
        margin: 0;
        color: var(--muted);
        line-height: 1.6;
      }

      form {
        margin-top: 28px;
      }

      label {
        display: block;
        margin-bottom: 10px;
        font-size: 0.95rem;
        font-weight: 600;
      }

      .row {
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
      }

      input {
        flex: 1 1 320px;
        min-width: 0;
        padding: 16px 18px;
        border-radius: 16px;
        border: 1px solid var(--line);
        background: rgba(255, 255, 255, 0.72);
        font: inherit;
        color: var(--ink);
      }

      button {
        border: 0;
        border-radius: 16px;
        padding: 16px 22px;
        font: inherit;
        font-weight: 700;
        background: linear-gradient(135deg, var(--accent), #f08f55);
        color: white;
        cursor: pointer;
      }

      .actions {
        margin-top: 16px;
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
      }

      .secondary {
        background: linear-gradient(135deg, #2d6f86, #4a95aa);
      }

      .panel-grid {
        margin-top: 22px;
        display: grid;
        gap: 16px;
        grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      }

      .result {
        padding: 20px;
        border-radius: 18px;
        background: rgba(255, 255, 255, 0.66);
        border: 1px solid var(--line);
      }

      .result strong {
        display: block;
        margin-bottom: 8px;
        font-size: 1.05rem;
      }

      .ok {
        color: var(--ok);
      }

      .error {
        color: var(--error);
      }

      code {
        font-family: "SFMono-Regular", "Consolas", monospace;
      }

      .file-list {
        margin: 0;
        padding-left: 18px;
        display: grid;
        gap: 8px;
      }

      .file-list span {
        color: var(--muted);
        margin-left: 8px;
      }

      .hint {
        margin-top: 18px;
        font-size: 0.92rem;
      }

      @media (max-width: 640px) {
        .card {
          padding: 24px;
          border-radius: 22px;
        }

        button,
        input {
          width: 100%;
        }
      }
    </style>
  </head>
  <body>
    <main class="card">
      <p>Cloudflare Worker Frontend</p>
      <h1>检查本地 Hono API 和桌面文件</h1>
      <p>页面部署在 Cloudflare 上，浏览器会直接请求你当前机器上的本地 API，所以可以检查 <code>127.0.0.1</code> 和桌面文件列表接口。</p>

      <form id="checker-form">
        <label for="api-base">本地 API 基础地址</label>
        <div class="row">
          <input id="api-base" name="api-base" value="http://127.0.0.1:3000" />
        </div>
        <div class="actions">
          <button type="button" id="check-hello">检测 /hello</button>
          <button type="button" id="check-files" class="secondary">读取 /files</button>
        </div>
      </form>

      <section class="panel-grid">
        <section class="result" id="hello-result">
          <strong>等待检测</strong>
          <span>点击“检测 /hello”后会请求本地 <code>/hello</code>。</span>
        </section>
        <section class="result" id="files-result">
          <strong>等待读取</strong>
          <span>点击“读取 /files”后会显示当前用户桌面下的文件列表。</span>
        </section>
      </section>

      <p class="hint">如果浏览器提示跨域失败，请确认本地 API 已开启 CORS。本项目已经默认开启。</p>
    </main>

    <script>${clientScript}</script>
  </body>
</html>`
}
