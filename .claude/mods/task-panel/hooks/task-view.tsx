/* @jsxRuntime classic */
/* @jsx h */
/* @jsxFrag Fragment */
import type { ElementTable, RenderElement } from 'claude-code'

import { isBlocked } from './tasks'
import type { Task } from './tasks'

export type TaskKit = Pick<ElementTable, 'Box' | 'Text'>

export const EMPTY_TEXT = 'このセッションにはまだタスクがありません'

const MARKS = {
  completed: '✔',
  in_progress: '◐',
  pending: '☐',
} as const

/**
 * The pane's body: how far along, then each task with its mark; the one in
 * progress bold with what is being done, the done ones dim.
 *
 * @param kit the surface's elements
 * @param tasks the session's tasks in id order
 * @returns the tree
 */
export function taskView(kit: TaskKit, tasks: readonly Task[]): RenderElement {
  const { Box, Text } = kit

  if (tasks.length === 0) {
    return <Text dimColor>{EMPTY_TEXT}</Text>
  }

  const done = tasks.filter(task => task.status === 'completed').length

  return (
    <Box flexDirection="column">
      <Text bold>{`${done}/${tasks.length} 完了`}</Text>
      <Text> </Text>
      {tasks.map(task => {
        const isDone = task.status === 'completed'
        const isActive = task.status === 'in_progress'
        const blocked = !isDone && isBlocked(task, tasks)

        return (
          <Box key={`task:${task.id}`} flexDirection="column">
            <Text dimColor={isDone} bold={isActive}>
              {`${MARKS[task.status]} ${task.subject}`}
              {blocked ? (
                <Text dimColor>{`  ⛓ #${task.blockedBy.join(', #')} 待ち`}</Text>
              ) : null}
            </Text>
            {isActive && task.activeForm ? (
              <Text dimColor>{`   └ ${task.activeForm}`}</Text>
            ) : null}
          </Box>
        )
      })}
    </Box>
  )
}
