import type {
  FsStat,
  PaneCloseArgs,
  PaneOpenArgs,
  TimerCall,
} from 'claude-code'

/**
 * The engine as `session.start` bound it from its `$`, each member spelled
 * `$.noun.event(...)` there; the engine refuses a module that keeps `$`.
 */
export type Host = {
  stat: (path: string) => Promise<FsStat>
  readFile: (path: string) => Promise<string>
  every: TimerCall
  invalidate: () => void
  openPane: (pane: PaneOpenArgs) => Promise<unknown>
  closePane: (pane: PaneCloseArgs) => Promise<void>
}
