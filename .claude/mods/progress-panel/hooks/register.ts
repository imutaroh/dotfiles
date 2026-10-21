import type { On, Timer } from 'claude-code'

import type { Host } from './host'
import { progressView } from './progress-view'
import type { Progress } from './progress-view'

export const COMMAND_NAME = 'progress'
export const PANE_ID = 'progress'
export const PANE_TITLE = 'Progress'
export const PROGRESS_PATH = '.claude/tmp/progress.md'
export const POLL_MS = 1000

/**
 * Registers the progress pane: `/progress` toggles it; while open, a poll of
 * the file's stat and Claude's edits and shell commands redraw it.
 *
 * @param on the engine's registrar
 */
export function register(on: On) {
  let host: Host | null = null
  let path = PROGRESS_PATH
  let isOpen = false
  let progress: Progress = { kind: 'missing', path }
  let stamp: string | null = null
  let poll: Timer | null = null
  let isRefreshing = false

  async function refresh(engine: Host): Promise<void> {
    if (isRefreshing) {
      return
    }

    isRefreshing = true

    try {
      const stat = await engine.stat(path).catch(() => null)
      const current = stat ? `${stat.mtimeMs}:${stat.size}` : 'missing'

      if (current === stamp) {
        return
      }

      stamp = current

      const text = stat ? await engine.readFile(path).catch(() => null) : null

      progress =
        text === null ? { kind: 'missing', path } : { kind: 'text', path, text }

      engine.invalidate()
    } finally {
      isRefreshing = false
    }
  }

  function stopPoll() {
    poll?.cancel()
    poll = null
  }

  on('session.start', async ($, e, next) => {
    path = `${e.cwd}/${PROGRESS_PATH}`
    progress = { kind: 'missing', path }

    try {
      await $.command.register({
        name: COMMAND_NAME,
        description: 'Toggle the panel showing .claude/tmp/progress.md',
      })

      host = {
        stat: target => $.fs.stat(target),
        readFile: target => $.fs.read(target),
        every: (ms, fn) => $.clock.every(ms, fn),
        invalidate: () => $.ui.invalidate('ui.render'),
        openPane: pane => $.ui.open(pane),
        closePane: pane => $.ui.close(pane),
      }
    } catch (error) {
      $.ui.log(`/progress was not registered: ${String(error)}`)
    }

    return next(e)
  })

  on('command.run', { command: COMMAND_NAME }, async ($, e, next) => {
    const engine = host

    if (!engine) {
      return next(e)
    }

    if (isOpen) {
      await engine.closePane({ id: PANE_ID })
      isOpen = false
      stopPoll()

      return { text: 'Progress panel hidden' }
    }

    stamp = null
    await refresh(engine)
    await engine.openPane({ id: PANE_ID, title: PANE_TITLE })
    isOpen = true

    stopPoll()
    poll = engine.every(POLL_MS, () => {
      void refresh(engine)
    })

    return { text: 'Progress panel shown' }
  })

  on('ui.close', { id: PANE_ID }, async ($, e, next) => {
    const result = await next(e)

    if (result.deny === undefined) {
      isOpen = false
      stopPoll()
    }

    return result
  })

  on('ui.render', { component: 'Pane' }, async ($, e, next) => {
    if (e.requestId !== PANE_ID) {
      return next(e)
    }

    const { Box, Text, Markdown } = await $.ui.resolve(e)

    return progressView({ Box, Text, Markdown }, progress)
  })

  on(
    'tool.call',
    { tool: ['Edit', 'Write', 'NotebookEdit', 'Bash'] },
    async ($, e, next) => {
      try {
        return await next(e)
      } finally {
        if (isOpen && host) {
          void refresh(host)
        }
      }
    },
  )
}
