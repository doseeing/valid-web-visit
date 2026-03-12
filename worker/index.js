const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Local Hono API Checker</title>
    <style>
      :root {
        --bg: #f6efe4;
        --panel: rgba(255, 252, 247, 0.86);
        --ink: #1d2433;
        --muted: #5b6271;
        --accent: #d85f3c;
        --accent-dark: #8b341c;
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
        width: min(720px, 100%);
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

      button:hover {
        filter: brightness(1.03);
      }

      .result {
        margin-top: 22px;
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
      <h1>检查本地 Hono API 是否在线</h1>
      <p>页面部署在 Cloudflare 上，但真正的 API 检查由你当前浏览器直接访问本机接口完成，所以可以检测 <code>127.0.0.1</code> 是否可用。</p>

      <form id="checker-form">
        <label for="api-url">本地 API 地址</label>
        <div class="row">
          <input id="api-url" name="api-url" value="http://127.0.0.1:3000/hello" />
          <button type="submit">开始检测</button>
        </div>
      </form>

      <section class="result" id="result">
        <strong>等待检测</strong>
        <span>点击按钮后会请求你本机的 <code>/hello</code> 接口。</span>
      </section>

      <p class="hint">如果浏览器提示跨域失败，请确认本地 API 已开启 CORS。本项目已经默认开启。</p>
    </main>

    <script>
      const form = document.getElementById('checker-form');
      const input = document.getElementById('api-url');
      const result = document.getElementById('result');

      form.addEventListener('submit', async (event) => {
        event.preventDefault();

        const url = input.value.trim();
        if (!url) {
          result.innerHTML = '<strong class="error">检测失败</strong><span>请输入一个有效的 API 地址。</span>';
          return;
        }

        result.innerHTML = '<strong>检测中</strong><span>正在请求 <code>' + url.replace(/</g, '&lt;') + '</code> ...</span>';

        try {
          const response = await fetch(url, {
            method: 'GET'
          });
          const text = await response.text();

          if (response.ok && text.trim() === 'world') {
            result.innerHTML = '<strong class="ok">接口可用</strong><span>收到响应：<code>' + text.replace(/</g, '&lt;') + '</code></span>';
            return;
          }

          result.innerHTML =
            '<strong class="error">接口已响应，但结果不符合预期</strong><span>HTTP ' +
            response.status +
            '，内容：<code>' +
            text.replace(/</g, '&lt;') +
            '</code></span>';
        } catch (error) {
          result.innerHTML =
            '<strong class="error">接口不可用</strong><span>' +
            (error && error.message ? error.message : '请求失败') +
            '</span>';
        }
      });
    </script>
  </body>
</html>`;

export default {
  async fetch() {
    return new Response(html, {
      headers: {
        'content-type': 'text/html; charset=UTF-8'
      }
    })
  }
}
