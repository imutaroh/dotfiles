import type { FsEntry, On, PaneCloseArgs, PaneOpenArgs, Timer, TimerCall } from 'claude-code'

import { taskView } from './task-view'
import { parseTask, sortTasks, taskDirOf } from './tasks'
import type { Task } from './tasks'

export const COMMAND_NAME = 'task-panel'
export const PANE_ID = 'tasks'
export const PANE_TITLE = 'Tasks'
export const POLL_MS = 1000

/**
 * The engine as `session.start` bound it from its `$`, each member spelled
 * `$.noun.event(...)` there; the engine refuses a module that keeps `$`.
 */
export type Host = {
  taskDir: () => Promise<string>
  list: (path: string) => Promise<FsEntry[]>
  readFile: (path: string) => Promise<string>
  every: TimerCall
  invalidate: () => void
  openPane: (pane: PaneOpenArgs) => Promise<unknown>
  closePane: (pane: PaneCloseArgs) => Promise<void>
}

/**
 * Registers the task pane: `/task-panel` toggles it; while open, a poll of the
 * task directory and Claude's task tool calls redraw it.
 *
 * @param on the engine's registrar
 */
export function register(on: On) {
  let host: Host | null = null
  let isOpen = false
  let tasks: Task[] = []
  let stamp: string | null = null
  let poll: Timer | null = null
  let isRefreshing = false

  async function refresh(engine: Host): Promise<void> {
    if (isRefreshing) {
      return
    }

    isRefreshing = true

    try {
      // Read each time: /clear starts a new session id, and a new directory.
      const dir = await engine.taskDir()
      const entries = (await engine.list(dir).catch(() => [])).filter(
        entry => entry.kind === 'file' && entry.name.endsWith('.json'),
      )
      const current = `${dir}|${entries
        .map(entry => `${entry.name}:${entry.mtimeMs}:${entry.size}`)
        .sort()
        .join(',')}`

      if (current === stamp) {
        return
      }

      stamp = current

      const read = await Promise.all(
        entries.map(entry =>
          engine.readFile(`${dir}/${entry.name}`).then(parseTask, () => null),
        ),
      )

      tasks = sortTasks(read.filter((task): task is Task => task !== null))
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
    try {
      await $.command.register({
        name: COMMAND_NAME,
        description: 'Toggle the panel showing this session\'s tasks',
      })

      const home = (await $.env.get('HOME')) ?? ''

      host = {
        taskDir: async () => taskDirOf(home, await $.session.id()),
        list: path => $.fs.list(path),
        readFile: path => $.fs.read(path),
        every: (ms, fn) => $.clock.every(ms, fn),
        invalidate: () => $.ui.invalidate('ui.render'),
        openPane: pane => $.ui.open(pane),
        closePane: pane => $.ui.close(pane),
      }
    } catch (error) {
      $.ui.log(`/task-panel was not registered: ${String(error)}`)
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

      return { text: 'Tasks panel hidden' }
    }

    stamp = null
    await refresh(engine)
    await engine.openPane({ id: PANE_ID, title: PANE_TITLE })
    isOpen = true

    stopPoll()
    poll = engine.every(POLL_MS, () => {
      void refresh(engine)
    })

    return { text: 'Tasks panel shown' }
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

    const { Box, Text } = await $.ui.resolve(e)

    return taskView({ Box, Text }, tasks)
  })

  on('tool.call', { tool: ['TaskCreate', 'TaskUpdate'] }, async ($, e, next) => {
    try {
      return await next(e)
    } finally {
      if (isOpen && host) {
        void refresh(host)
      }
    }
  })
}
