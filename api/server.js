import { serve } from '@hono/node-server'
import { cors } from 'hono/cors'
import { Hono } from 'hono'

const app = new Hono()

app.use('*', cors())

app.get('/', (c) => {
  return c.json({
    message: 'Local Hono API is running',
    hello: '/hello'
  })
})

app.get('/hello', (c) => c.text('world'))

const port = Number(process.env.PORT || 3000)

serve(
  {
    fetch: app.fetch,
    port
  },
  (info) => {
    console.log(`Local Hono API listening on http://127.0.0.1:${info.port}`)
  }
)
