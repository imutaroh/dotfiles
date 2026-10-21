import type { On, RenderInput } from 'claude-code'
import { describe, expect, mock, test, tier } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import { POLL_MS } from '../hooks/register'
import { EMPTY_TEXT } from '../hooks/task-view'
import { parseTask, sortTasks } from '../hooks/tasks'

tier('user')

const DIR = '/home/me/.claude/tasks/session-9c181913'

const TASKS = {
  command: 'task-panel',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: true, columns: 160 },
} as const

const PANE: RenderInput<'Pane'> = {
  component: 'Pane',
  surface: 'terminal',
  requestId: 'tasks',
  viewport: { columns: 160, rows: 40 },
  props: {
    title: 'Tasks',
    isFocused: false,
    bodyColumns: 80,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
}

function taskFile(id: string, subject: string, status: string, extra = {}) {
  return JSON.stringify({ id, subject, status, blocks: [], blockedBy: [], ...extra })
}

describe('tasks', () => {
  test('parseTask reads a task file and refuses anything else', () => {
    expect(
      parseTask(taskFile('2', '直す', 'in_progress', { activeForm: '直し中', blockedBy: ['1'] })),
    ).toEqual({
      id: '2',
      subject: '直す',
      activeForm: '直し中',
      status: 'in_progress',
      blockedBy: ['1'],
    })
    expect(parseTask('{"id":1}')).toBeNull()
    expect(parseTask('壊れた')).toBeNull()
  })

  test('sortTasks orders ids as numbers', () => {
    const ids = sortTasks(
      ['10', '2', '1'].map(id => ({
        id,
        subject: id,
        activeForm: null,
        status: 'pending' as const,
        blockedBy: [],
      })),
    ).map(task => task.id)

    expect(ids).toEqual(['1', '2', '10'])
  })
})

describe('register', () => {
  /**
   * A session 9c181913-… whose task directory holds `files`.
   */
  function world(on: On, files: Map<string, { text: string; mtimeMs: number }>) {
    const clock = mock.clock(on)

    on('session.start', ($, e) => ({ cwd: e.cwd }))
    on('session.id', () => ({ value: '9c181913-aaaa-bbbb-cccc-dddddddddddd' }))
    on('env.get', () => ({ value: '/home/me' }))
    on('command.register', ($, e) => ({ value: { command: e.name } }))
    on('ui.invalidate', () => ({ value: undefined }))
    on('ui.open', () => ({ value: undefined }))
    on('ui.close', () => ({ value: undefined }))

    on('fs.list', ($, e) => {
      if (e.path !== DIR) {
        throw new Error(`ENOENT: ${e.path}`)
      }

      return {
        value: [...files].map(([name, file]) => ({
          name,
          kind: 'file' as const,
          size: file.text.length,
          mtimeMs: file.mtimeMs,
          isLink: false,
        })),
      }
    })

    on('fs.read', ($, e) => {
      const file = files.get(e.path.slice(DIR.length + 1))

      if (!file) {
        throw new Error(`ENOENT: ${e.path}`)
      }

      return { value: file.text }
    })

    return { clock }
  }

  async function opens($: Engine) {
    await $.session.start({ surface: 'terminal', isInteractive: true, cwd: '/work' })

    return $.command.run(TASKS)
  }

  test('/task-panel draws the progress and each task in id order', async ($, on) => {
    world(
      on,
      new Map([
        ['2.json', { text: taskFile('2', '実装する', 'in_progress', { activeForm: '実装中' }), mtimeMs: 1 }],
        ['1.json', { text: taskFile('1', '調べる', 'completed'), mtimeMs: 1 }],
        ['3.json', { text: taskFile('3', 'テストする', 'pending', { blockedBy: ['2'] }), mtimeMs: 1 }],
      ]),
    )

    expect(await opens($)).toEqual({ text: 'Tasks panel shown' })

    const ui = await $.ui.mount({ plugin: 'task-panel', ...PANE })
    const texts = (await ui.findAll({ type: 'Text' })).map(found => found.text)

    expect(texts).toContain('1/3 完了')
    expect(texts).toContain('   └ 実装中')
    expect(texts.indexOf('✔ 調べる')).toBeLessThan(texts.indexOf('◐ 実装する'))
    expect(texts).toContain('☐ テストする  ⛓ #2 待ち')
  })

  test('without a task directory the pane says there are none', async ($, on) => {
    world(on, new Map())

    await opens($)

    const ui = await $.ui.mount({ plugin: 'task-panel', ...PANE })

    expect(await ui.find({ type: 'Text', text: EMPTY_TEXT })).toBeDefined()
  })

  test('a task changed on disk is drawn after the next poll', async ($, on) => {
    const files = new Map([['1.json', { text: taskFile('1', '調べる', 'pending'), mtimeMs: 1 }]])
    const { clock } = world(on, files)

    await opens($)
    files.set('1.json', { text: taskFile('1', '調べる', 'completed'), mtimeMs: 2 })
    await clock.advance(POLL_MS)

    const ui = await $.ui.mount({ plugin: 'task-panel', ...PANE })

    expect(await ui.find({ type: 'Text', text: '1/1 完了' })).toBeDefined()
  })

  test('/task-panel again closes the pane', async ($, on) => {
    world(on, new Map())

    await opens($)

    expect(await $.command.run(TASKS)).toEqual({ text: 'Tasks panel hidden' })
  })
})
