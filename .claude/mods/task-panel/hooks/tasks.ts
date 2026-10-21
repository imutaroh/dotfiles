/**
 * The session's tasks as the built-in task tools write them, one JSON file
 * per task under `~/.claude/tasks/session-<first 8 of the session id>/`.
 */

export type TaskStatus = 'pending' | 'in_progress' | 'completed'

export type Task = {
  id: string
  subject: string
  activeForm: string | null
  status: TaskStatus
  blockedBy: string[]
}

export const TASKS_ROOT = '.claude/tasks'

/**
 * The directory the task tools write this session's tasks to.
 *
 * @param home the user's home directory
 * @param sessionId the session's id
 * @returns the directory's path
 */
export function taskDirOf(home: string, sessionId: string): string {
  return `${home}/${TASKS_ROOT}/session-${sessionId.slice(0, 8)}`
}

/**
 * One task file read as a task, or null when it is not one.
 *
 * @param text the file's text
 * @returns the task
 */
export function parseTask(text: string): Task | null {
  let value: unknown

  try {
    value = JSON.parse(text)
  } catch {
    return null
  }

  if (typeof value !== 'object' || value === null) {
    return null
  }

  const { id, subject, activeForm, status, blockedBy } = value as Record<
    string,
    unknown
  >

  if (typeof id !== 'string' || typeof subject !== 'string') {
    return null
  }

  return {
    id,
    subject,
    activeForm: typeof activeForm === 'string' ? activeForm : null,
    status:
      status === 'in_progress' || status === 'completed' ? status : 'pending',
    blockedBy: Array.isArray(blockedBy)
      ? blockedBy.filter((item): item is string => typeof item === 'string')
      : [],
  }
}

/**
 * The tasks in id order, numbers compared as numbers.
 *
 * @param tasks the tasks as read
 * @returns them sorted
 */
export function sortTasks(tasks: readonly Task[]): Task[] {
  return [...tasks].sort(
    (a, b) => Number(a.id) - Number(b.id) || a.id.localeCompare(b.id),
  )
}

/**
 * Whether a task still waits on one that is not done.
 *
 * @param task the task
 * @param tasks every task of the session
 * @returns true while a blocker is open
 */
export function isBlocked(task: Task, tasks: readonly Task[]): boolean {
  return task.blockedBy.some(id =>
    tasks.some(other => other.id === id && other.status !== 'completed'),
  )
}
