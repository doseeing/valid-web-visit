import { renderPage } from './app.js'

export default {
  async fetch() {
    return new Response(renderPage(), {
      headers: {
        'content-type': 'text/html; charset=UTF-8'
      }
    })
  }
}
