import { renderPage } from './app.js'
import { getAsset, getAssetResponse } from './generated/web-icons.js'

export function handleRequest(request) {
  const { pathname } = new URL(request.url)

  if (pathname === '/favicon.ico') {
    return Response.redirect(new URL('/favicon-32x32.png', request.url), 302)
  }

  const asset = getAsset(pathname)
  if (asset) {
    return getAssetResponse(asset)
  }

  return new Response(renderPage(), {
    headers: {
      'content-type': 'text/html; charset=UTF-8'
    }
  })
}

export default {
  async fetch(request) {
    return handleRequest(request)
  }
}
