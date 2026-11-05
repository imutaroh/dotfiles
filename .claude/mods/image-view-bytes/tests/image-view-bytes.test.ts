import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

import { decodedBytes, fitCells, fitRow, imageNumbers, isWholePng, pngSize, THUMBNAIL_PIXELS } from '../hooks/layout'

// A PNG's head and tail; `filler` bytes between them stand for the picture, at most 3 KiB at a time.
function pngBytes(width: number, height: number, filler = 0): number[] {
  const head = new Uint8Array(33)
  head.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52])
  const view = new DataView(head.buffer)
  view.setUint32(16, width)
  view.setUint32(20, height)
  const tail = [0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]
  return [...head, ...new Array<number>(filler).fill(0), ...tail]
}

function png(width: number, height: number, filler = 0): string {
  return btoa(String.fromCharCode(...pngBytes(width, height, filler)))
}

// The same shape of base64 at any size, without building the bytes: only its ends are looked at.
function bigPng(width: number, height: number, bytes: number): string {
  const small = png(width, height, 3)
  const head = small.slice(0, 32)
  const tail = small.slice(-16)
  return head + 'A'.repeat(Math.ceil((bytes * 4) / 3 / 4) * 4) + tail
}

test('image numbers come from the draft, deduplicated, in order', () => {
  expect(imageNumbers('look [Image #2] and [Image #1] again [Image #2]')).toEqual([2, 1])
  expect(imageNumbers('[Image 1] [image #3] #4')).toEqual([])
})

test('PNG size is read from the IHDR header', () => {
  expect(pngSize(png(1630, 632))).toEqual({ width: 1630, height: 632 })
  expect(pngSize(btoa('\xff\xd8\xff\xe0 this is a jpeg, not a png...'))).toBeNull()
})

test('a PNG cut short is told from a whole one', () => {
  for (const filler of [0, 1, 2, 3]) {
    const bytes = pngBytes(10, 10, filler)
    expect(isWholePng(btoa(String.fromCharCode(...bytes)))).toBe(true)
    expect(isWholePng(btoa(String.fromCharCode(...bytes.slice(0, -5))))).toBe(false)
  }
})

test('the decoded size of base64 counts its padding', () => {
  expect(decodedBytes(btoa('abc'))).toBe(3)
  expect(decodedBytes(btoa('ab'))).toBe(2)
  expect(decodedBytes(btoa('a'))).toBe(1)
})

test('thumbnails keep aspect ratio within the tile', () => {
  // Square: 6 rows tall, twice as many columns because cells are tall.
  expect(fitCells({ width: 500, height: 500 })).toEqual({ columns: 12, rows: 6 })
  // Very wide: capped at 32 columns, rows shrink to match.
  expect(fitCells({ width: 3000, height: 500 })).toEqual({ columns: 32, rows: 3 })
  // Very tall: never narrower than 4 columns.
  expect(fitCells({ width: 100, height: 2000 })).toEqual({ columns: 4, rows: 6 })
})

test('a row of tiles shrinks to fit the band so it never scrolls', () => {
  const square = { width: 500, height: 500 }
  // Plenty of room: full 6-row tiles.
  expect(fitRow([square], 20, 120)).toEqual([{ columns: 12, rows: 6 }])
  // A short band: border and label take 3 rows, so the picture gets the rest.
  expect(fitRow([square], 7, 120)).toEqual([{ columns: 8, rows: 4 }])
  // A narrow band: three 6-row squares need 3 * 14 + 2 = 44 columns; 40 forces 5 rows.
  expect(fitRow([square, square, square], 20, 40)).toEqual([
    { columns: 10, rows: 5 },
    { columns: 10, rows: 5 },
    { columns: 10, rows: 5 },
  ])
})

const BAND = {
  plugin: 'image-view-bytes',
  component: 'AbovePrompt',
  requestId: 'above-prompt',
  viewport: { columns: 120, rows: 40 },
  props: { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 120, scroll: { offset: 0, bodyRows: 20 }, view: {} },
} as const

const DIR = '/tmp/claude-501/-work/sess-1/images'

// One session whose draft and whose files the test holds.
function session(on: Parameters<TestBody>[1], state: { draft: string; files: Record<string, string> }) {
  on('session.start', () => ({ cwd: '/work' }))
  on('prompt.read', () => ({ value: { text: state.draft, cursor: state.draft.length } }))
  on('env.get', () => ({ value: '/tmp/claude-501' }))
  on('session.id', () => ({ value: 'sess-1' }))
  // Another project's folder and a stray file sit beside the one holding this session.
  const entry = { size: 0, mtimeMs: 0, isLink: false }
  on('fs.list', () => ({
    value: [
      { name: '-other', kind: 'dir', ...entry },
      { name: 'notes.txt', kind: 'file', ...entry },
      { name: '-work', kind: 'dir', ...entry },
    ],
  }))
  on('fs.exists', ($, e) => ({ value: e.path === DIR || e.path in state.files }))
  on('fs.read', ($, e) => ({ value: { base64: state.files[e.path] ?? '' } }))
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['engine band'] }))
}

test('a pasted image shows as bytes without another keystroke and clears when the draft does', async ($, on) => {
  const clock = mock.clock(on)
  const state = { draft: 'see [Image #1] [Image #2]', files: { [`${DIR}/1.png`]: png(800, 400) } as Record<string, string> }
  session(on, state)

  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await clock.advance(200)

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  const image = await ui.find({ type: 'Image' })
  expect(image?.props).toMatchObject({ source: { png: state.files[`${DIR}/1.png`] }, columns: 24, rows: 6 })
  // #2 has no cached file, so it gets a placeholder tile instead of a broken Image.
  expect(await ui.find({ type: 'Text', text: 'no preview' })).toBeDefined()
  await ui.unmount()

  // Sending the prompt empties the box.
  state.draft = ''
  await clock.advance(200)
  const after = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await after.find({ type: 'Image' })).toBeUndefined()
  expect(await after.find({ type: 'Text', text: 'engine band' })).toBeDefined()
})

test('a file still being written is read again on the next poll', async ($, on) => {
  const clock = mock.clock(on)
  const whole = png(800, 400)
  const state = { draft: '[Image #1]', files: { [`${DIR}/1.png`]: whole.slice(0, 48) } as Record<string, string> }
  session(on, state)

  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await clock.advance(200)
  const before = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await before.find({ type: 'Image' })).toBeUndefined()
  await before.unmount()

  state.files[`${DIR}/1.png`] = whole
  await clock.advance(200)
  const after = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await after.find({ type: 'Image' }))?.props).toMatchObject({ source: { png: whole } })
})

test('a big screenshot is sent as a smaller copy', async ($, on) => {
  const clock = mock.clock(on)
  const original = bigPng(2560, 1080, 1024 * 1024)
  const copy = png(640, 270)
  const state = { draft: '[Image #1]', files: { [`${DIR}/1.png`]: original } as Record<string, string> }
  session(on, state)
  const calls: (readonly string[])[] = []
  on('process.run', ($, e) => {
    calls.push(e.argv)
    state.files[`${DIR}/thumbnail-1.png`] = copy
    return { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await clock.advance(200)

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Image' }))?.props).toMatchObject({ source: { png: copy } })
  expect(calls).toEqual([['sips', '-Z', String(THUMBNAIL_PIXELS), `${DIR}/1.png`, '--out', `${DIR}/thumbnail-1.png`]])

  // Unchanged, the next polls don't shrink it again.
  await clock.advance(1000)
  expect(calls.length).toBe(1)
})

test('without sips the original goes if it fits, and one too big is given up on once', async ($, on) => {
  const clock = mock.clock(on)
  const fits = bigPng(2560, 1080, 1024 * 1024)
  const tooBig = bigPng(5120, 2880, 3 * 1024 * 1024)
  const state = { draft: '[Image #1] [Image #2]', files: { [`${DIR}/1.png`]: fits, [`${DIR}/2.png`]: tooBig } as Record<string, string> }
  session(on, state)
  let runs = 0
  on('process.run', () => {
    runs++
    return { value: { exitCode: 1, stdout: '', stderr: 'no sips', isStdoutTruncated: false, isStderrTruncated: false } }
  })

  await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })
  await clock.advance(200)

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Image' }))?.props).toMatchObject({ source: { png: fits } })
  expect(await ui.find({ type: 'Text', text: 'no preview' })).toBeDefined()
  await clock.advance(1000)
  expect(runs).toBe(2)
})
