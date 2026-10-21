/* @jsxRuntime classic */
/* @jsx h */
/* @jsxFrag Fragment */
import type { ElementTable, RenderElement } from 'claude-code'

/**
 * What the pane shows: the file's text, or that it is missing.
 */
export type Progress =
  | { kind: 'text'; path: string; text: string }
  | { kind: 'missing'; path: string }

export type ProgressKit = Pick<ElementTable, 'Box' | 'Text' | 'Markdown'>

/**
 * The most a Markdown element draws, as its props allow.
 */
export const MARKDOWN_MAX_CHARS = 10000

export const MISSING_TEXT = 'progress.md がありません'

/**
 * The file's text as a Markdown element takes it: CRLF folded, control
 * characters other than tab and newline dropped, cut at the element's cap.
 *
 * @param text the file's text
 * @returns the text to draw
 */
export function drawableTextOf(text: string): string {
  const cleaned = text
    .replace(/\r\n?/g, '\n')
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '')

  return cleaned.length > MARKDOWN_MAX_CHARS
    ? `${cleaned.slice(0, MARKDOWN_MAX_CHARS - 1)}…`
    : cleaned
}

/**
 * The pane's body: the file as markdown, or a line saying it is missing.
 *
 * @param kit the surface's elements
 * @param progress what the last read found
 * @returns the tree
 */
export function progressView(
  kit: ProgressKit,
  progress: Progress,
): RenderElement {
  const { Box, Text, Markdown } = kit

  if (progress.kind === 'missing') {
    return (
      <Box flexDirection="column">
        <Text>{MISSING_TEXT}</Text>
        <Text dimColor>{progress.path}</Text>
      </Box>
    )
  }

  return <Markdown text={drawableTextOf(progress.text)} />
}
