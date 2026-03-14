import { readdir } from 'node:fs/promises'
import { homedir } from 'node:os'
import path from 'node:path'
import { serve } from '@hono/node-server'
import { cors } from 'hono/cors'
import { Hono } from 'hono'

const app = new Hono()

app.use('*', cors())

app.get('/', (c) => {
  return c.json({
    message: 'Local Bridge API is running',
    hello: '/hello',
    files: '/files'
  })
})

app.get('/hello', (c) => c.text('world'))

app.get('/files', async (c) => {
  const desktopPath = path.join(homedir(), 'Desktop')

  try {
    const entries = await readdir(desktopPath, { withFileTypes: true })
    const files = entries
      .map((entry) => ({
        name: entry.name,
        type: entry.isDirectory() ? 'directory' : entry.isFile() ? 'file' : 'other'
      }))
      .sort((a, b) => a.name.localeCompare(b.name))

    return c.json({
      path: desktopPath,
      count: files.length,
      files
    })
  } catch (error) {
    return c.json(
      {
        error: 'Failed to read desktop files',
        message: error instanceof Error ? error.message : 'Unknown error',
        path: desktopPath
      },
      500
    )
  }
})

const port = Number(process.env.PORT || 3000)

serve(
  {
    fetch: app.fetch,
    port
  },
  (info) => {
    console.log(`Local Bridge API listening on http://127.0.0.1:${info.port}`)
  }
)
