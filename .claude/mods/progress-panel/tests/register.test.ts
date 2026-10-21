import type { Args, On, RenderInput } from 'claude-code'
import { describe, expect, mock, test, tier } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import { MISSING_TEXT } from '../hooks/progress-view'
import { POLL_MS } from '../hooks/register'

tier('user')

const FILE = '/work/.claude/tmp/progress.md'

const PROGRESS = {
  command: 'progress',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: true, columns: 160 },
} as const

const PANE: RenderInput<'Pane'> = {
  component: 'Pane',
  surface: 'terminal',
  requestId: 'progress',
  viewport: { columns: 160, rows: 40 },
  props: {
    title: 'Progress',
    isFocused: false,
    bodyColumns: 80,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
}

describe('register', () => {
  /**
   * A session in /work whose file system holds `files`, keeping the panes
   * opened and closed.
   */
  function world(on: On, files: Map<string, { text: string; mtimeMs: number }>) {
    const opened: Args<'ui.open'>[] = []
    const closed: Args<'ui.close'>[] = []
    const clock = mock.clock(on)

    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('ui.invalidate', () => ({ value: undefined }))

    on('ui.open', ($, e) => {
      opened.push(e)

      return { value: undefined }
    })

    on('ui.close', ($, e) => {
      closed.push(e)

      return { value: undefined }
    })

    on('fs.stat', ($, e) => {
      const file = files.get(e.path)

      if (!file) {
        throw new Error(`ENOENT: ${e.path}`)
      }

      return {
        value: {
          kind: 'file',
          size: file.text.length,
          mtimeMs: file.mtimeMs,
          isLink: false,
        },
      }
    })

    on('fs.read', ($, e) => {
      const file = files.get(e.path)

      if (!file) {
        throw new Error(`ENOENT: ${e.path}`)
      }

      return { value: file.text }
    })

    return { opened, closed, clock }
  }

  async function opens($: Engine) {
    await $.session.start({
      surface: 'terminal',
      isInteractive: true,
      cwd: '/work',
    })

    return $.command.run(PROGRESS)
  }

  test('/progress opens the pane and draws progress.md', async ($, on) => {
    const files = new Map([[FILE, { text: '# 進捗\n\n- [x] 調査', mtimeMs: 1 }]])
    const { opened } = world(on, files)

    expect(await opens($)).toEqual({ text: 'Progress panel shown' })
    expect(opened).toEqual([{ id: 'progress', title: 'Progress' }])

    const ui = await $.ui.mount({ plugin: 'progress-panel', ...PANE })

    expect((await ui.find({ type: 'Markdown' }))?.text).toBe(
      '# 進捗\n\n- [x] 調査',
    )
  })

  test('without progress.md the pane says it is missing', async ($, on) => {
    world(on, new Map())

    expect(await opens($)).toEqual({ text: 'Progress panel shown' })

    const ui = await $.ui.mount({ plugin: 'progress-panel', ...PANE })

    expect(await ui.find({ type: 'Markdown' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: MISSING_TEXT })).toBeDefined()
  })

  test('a changed file is drawn after the next poll', async ($, on) => {
    const files = new Map([[FILE, { text: 'before', mtimeMs: 1 }]])
    const { clock } = world(on, files)

    await opens($)
    files.set(FILE, { text: 'after', mtimeMs: 2 })
    await clock.advance(POLL_MS)

    const ui = await $.ui.mount({ plugin: 'progress-panel', ...PANE })

    expect((await ui.find({ type: 'Markdown' }))?.text).toBe('after')
  })

  test('/progress again closes the pane and says so', async ($, on) => {
    const { closed } = world(on, new Map())

    await opens($)

    expect(await $.command.run(PROGRESS)).toEqual({
      text: 'Progress panel hidden',
    })
    expect(closed.map(pane => pane.id)).toEqual(['progress'])
  })
})
