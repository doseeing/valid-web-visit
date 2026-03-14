import { readFileSync, readdirSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const generatedDir = path.resolve(scriptDir, '..', 'generated')
const modulePath = path.join(generatedDir, 'web-icons.js')

const entries = readdirSync(generatedDir)
  .filter((name) => name !== 'web-icons.js')
  .sort()
  .map((name) => {
    const filePath = path.join(generatedDir, name)
    const isManifest = name.endsWith('.webmanifest')
    return {
      pathname: `/${name}`,
      body: readFileSync(filePath, isManifest ? 'utf8' : undefined),
      contentType: isManifest ? 'application/manifest+json; charset=UTF-8' : 'image/png'
    }
  })

const lines = [
  'const assetMap = new Map(['
]

for (const entry of entries) {
  if (typeof entry.body === 'string') {
    lines.push(
      `  [${JSON.stringify(entry.pathname)}, { contentType: ${JSON.stringify(entry.contentType)}, text: ${JSON.stringify(entry.body)}, cacheControl: "public, max-age=86400" }],`
    )
    continue
  }

  lines.push(
    `  [${JSON.stringify(entry.pathname)}, { contentType: ${JSON.stringify(entry.contentType)}, base64: ${JSON.stringify(entry.body.toString('base64'))}, cacheControl: "public, max-age=86400" }],`
  )
}

lines.push('])')
lines.push('')
lines.push('function decodeBase64(base64) {')
lines.push('  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0))')
lines.push('}')
lines.push('')
lines.push('export function getAsset(pathname) {')
lines.push('  return assetMap.get(pathname) || null')
lines.push('}')
lines.push('')
lines.push('export function getAssetResponse(asset) {')
lines.push('  return new Response(asset.text ?? decodeBase64(asset.base64), {')
lines.push('    headers: {')
lines.push("      'content-type': asset.contentType,")
lines.push("      'cache-control': asset.cacheControl")
lines.push('    }')
lines.push('  })')
lines.push('}')
lines.push('')

writeFileSync(modulePath, `${lines.join('\n')}\n`)
