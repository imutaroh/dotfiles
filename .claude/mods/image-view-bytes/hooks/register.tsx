import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { PastedImage } from '../types'
import { decodedBytes, fitRow, imageNumbers, isWholePng, PNG_LIMIT, pngSize, SHRINK_ABOVE, THUMBNAIL_PIXELS } from './layout'
import type { Size } from './layout'

// Pasting an image raises no prompt.edit (the tag only shows up on the next keystroke),
// so the draft is polled instead.
const POLL_MS = 200

type Picture = { png: string; size: Size | null }

const images = atom({ plugin: 'image-view-bytes', key: 'images' } as const, [] as PastedImage[])

let tmpRoot: string | undefined
let found: { sessionId: string; dir: string } | undefined
// The image numbers last drawn, so an unchanged draft doesn't rewrite state; undefined
// while a drawn image's file is still missing or cut, so the next poll looks again.
let shownKey: string | undefined
let isChecking = false
// What each file in the draft came to; null for one that will not draw, so it isn't tried again.
const pictures = new Map<string, Picture | null>()

// Claude Code caches each paste as <tmp>/<project>/<session>/images/<n>.png. The project
// folder is named after a working directory that may since have moved, so find it by the
// session id instead of rebuilding it.
async function imagesDir($: EngineInterface): Promise<string | undefined> {
  const sessionId = await $.session.id()
  if (found?.sessionId === sessionId) return found.dir
  if (tmpRoot === undefined) {
    const fromEnv = await $.env.get('CLAUDE_CODE_TMPDIR')
    tmpRoot = fromEnv ?? `/tmp/claude-${(await $.process.run(['id', '-u'])).stdout.trim()}`
  }
  const entries = await $.fs.list(tmpRoot).catch(() => [])
  for (const entry of entries) {
    const dir = `${tmpRoot}/${entry.name}/${sessionId}/images`
    if (entry.kind === 'dir' && (await $.fs.exists(dir))) {
      found = { sessionId, dir }
      return dir
    }
  }
  return undefined
}

function toPicture(base64: string): Picture | null {
  const size = pngSize(base64)
  return size !== null && isWholePng(base64) ? { png: base64, size } : null
}

function readBytes($: EngineInterface, path: string): Promise<string | undefined> {
  // Rejects over $.fs.read's 4 MiB cap.
  return $.fs.read(path, { as: 'bytes' }).then(
    ({ base64 }) => base64,
    () => undefined,
  )
}

// sips comes with macOS. Elsewhere this answers null and the original is sent if it fits.
async function shrink($: EngineInterface, path: string, thumbnail: string): Promise<Picture | null> {
  const run = await $.process.run(['sips', '-Z', String(THUMBNAIL_PIXELS), path, '--out', thumbnail]).catch(() => undefined)
  if (run?.exitCode !== 0) return null
  const base64 = await readBytes($, thumbnail)
  const picture = base64 === undefined ? null : toPicture(base64)
  return picture !== null && decodedBytes(picture.png) <= PNG_LIMIT ? picture : null
}

// Sends the picture itself instead of naming the file: a terminal that doesn't read image files
// (Herdr's desktop app, or any over ssh) draws a blank box for a name, and says so only in the debug log.
// Answers undefined while the file isn't whole yet, so the next poll reads it again.
async function load($: EngineInterface, path: string, thumbnail: string): Promise<Picture | null | undefined> {
  const base64 = await readBytes($, path)
  const whole = base64 === undefined ? undefined : toPicture(base64)
  if (whole === null) return undefined
  if (whole !== undefined && decodedBytes(whole.png) <= SHRINK_ABOVE) return whole
  const small = await shrink($, path, thumbnail)
  if (small !== null) return small
  return whole !== undefined && decodedBytes(whole.png) <= PNG_LIMIT ? whole : null
}

async function describe($: EngineInterface, dir: string | undefined, n: number): Promise<PastedImage> {
  const path = `${dir}/${n}.png`
  if (dir === undefined || !(await $.fs.exists(path))) return { n, png: null, size: null }
  if (!pictures.has(path)) {
    const picture = await load($, path, `${dir}/thumbnail-${n}.png`)
    if (picture === undefined) return { n, png: null, size: null }
    pictures.set(path, picture)
  }
  const picture = pictures.get(path)
  return { n, png: picture?.png ?? null, size: picture?.size ?? null }
}

async function show($: EngineInterface, draft: string) {
  const numbers = imageNumbers(draft)
  const key = numbers.join(',')
  if (key === shownKey) return
  const dir = numbers.length > 0 ? await imagesDir($) : undefined
  const list: PastedImage[] = []
  for (const n of numbers) list.push(await describe($, dir, n))
  const paths = numbers.map(n => `${dir}/${n}.png`)
  for (const path of pictures.keys()) if (!paths.includes(path)) pictures.delete(path)
  shownKey = paths.every(path => pictures.has(path)) ? key : undefined
  await update($, images, () => list)
}

async function check($: EngineInterface) {
  if (isChecking) return
  isChecking = true
  try {
    await show($, (await $.prompt.read()).text)
  } finally {
    isChecking = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    $.clock.every(POLL_MS, () => check($))
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.surface !== 'terminal' || e.props.hasSurvey) return next(e)
    const list = await read($, images)
    if (list.length === 0) return next(e)

    const { Box, Image, Text } = $.ui.resolve(e)
    const cells = fitRow(list.map(image => image.size), e.props.maxRows, e.props.bodyColumns)
    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Box flexDirection="row" columnGap={1}>
          {list.map((image, i) => {
            const { columns, rows } = cells[i] ?? { columns: 4, rows: 1 }
            return (
              <Box flexDirection="column" alignItems="center" borderStyle="round" borderDimColor>
                {image.png === null ? (
                  <Box width={columns} height={rows} alignItems="center" justifyContent="center">
                    <Text dimColor wrap="truncate">no preview</Text>
                  </Box>
                ) : (
                  <Image
                    key={`image-${image.n}`}
                    source={{ png: image.png }}
                    columns={columns}
                    rows={rows}
                    alt={`[Image #${image.n}]`}
                  />
                )}
                <Text dimColor>#{image.n}</Text>
              </Box>
            )
          })}
        </Box>
        {below}
      </Box>
    )
  })
}
