import { describe, expect, it } from 'vitest'
import { buildFilesResult, buildHelloResult, renderPage } from './app.js'
import { handleRequest } from './index.js'

describe('buildHelloResult', () => {
  it('returns success when hello endpoint responds with world', () => {
    expect(buildHelloResult({ ok: true, status: 200, text: 'world', url: 'http://127.0.0.1:3000/hello' })).toEqual({
      statusClass: 'ok',
      title: '接口可用',
      body: '收到响应：<code>world</code>'
    })
  })

  it('returns validation error for empty url', () => {
    expect(buildHelloResult({ url: '' })).toEqual({
      statusClass: 'error',
      title: '检测失败',
      body: '请输入一个有效的 API 地址。'
    })
  })
})

describe('buildFilesResult', () => {
  it('renders file names and types', () => {
    const result = buildFilesResult({
      ok: true,
      status: 200,
      data: {
        files: [
          { name: 'note.txt', type: 'file' },
          { name: 'photos', type: 'directory' }
        ]
      }
    })

    expect(result.statusClass).toBe('ok')
    expect(result.title).toContain('2 项')
    expect(result.body).toContain('note.txt')
    expect(result.body).toContain('directory')
  })

  it('escapes unsafe html in file names', () => {
    const result = buildFilesResult({
      ok: true,
      status: 200,
      data: {
        files: [{ name: '<script>alert(1)</script>', type: 'file' }]
      }
    })

    expect(result.body).not.toContain('<script>')
    expect(result.body).toContain('&lt;script&gt;alert(1)&lt;/script&gt;')
  })
})

describe('renderPage', () => {
  it('contains both hello and files actions', () => {
    const html = renderPage()

    expect(html).toContain('检测 /hello')
    expect(html).toContain('读取 /files')
    expect(html).toContain('当前用户桌面下的文件列表')
  })

  it('includes favicon and manifest links', () => {
    const html = renderPage()

    expect(html).toContain('href="/favicon.ico"')
    expect(html).toContain('href="/favicon-32x32.png"')
    expect(html).toContain('href="/apple-touch-icon.png"')
    expect(html).toContain('href="/site.webmanifest"')
  })
})

describe('worker assets', () => {
  it('serves the web manifest', async () => {
    const response = handleRequest(new Request('https://example.com/site.webmanifest'))

    expect(response.headers.get('content-type')).toContain('application/manifest+json')
    expect(await response.text()).toContain('"icons"')
  })

  it('redirects favicon.ico to the generated PNG favicon', () => {
    const response = handleRequest(new Request('https://example.com/favicon.ico'))

    expect(response.status).toBe(302)
    expect(response.headers.get('location')).toBe('https://example.com/favicon-32x32.png')
  })
})
