// 高亮：存成 ==文字==（Obsidian、Typora 都认这个写法）
// 读：把文字里的 ==...== 变成高亮；写：高亮写回 ==...==
// 快捷键 ⌘⇧H；直接打 ==文字== 也会自动变成高亮

import { $markSchema, $remark, $command, $inputRule, $useKeymap } from '@milkdown/kit/utils'
import { commandsCtx } from '@milkdown/kit/core'
import { toggleMark } from '@milkdown/kit/prose/commands'
import { markRule } from '@milkdown/kit/prose'

const PATTERN = /==([^=\n]+?)==/g

// 在 Markdown 语法树里找 ==...==（代码里的不算，因为代码不是 text 节点）
function splitHighlights(node) {
  if (!node.children) return
  const out = []
  for (const child of node.children) {
    if (child.type !== 'text' || !child.value.includes('==')) {
      splitHighlights(child)
      out.push(child)
      continue
    }
    let last = 0
    for (const m of child.value.matchAll(PATTERN)) {
      if (m.index > last) out.push({ type: 'text', value: child.value.slice(last, m.index) })
      out.push({ type: 'highlight', children: [{ type: 'text', value: m[1] }] })
      last = m.index + m[0].length
    }
    if (last < child.value.length) out.push({ type: 'text', value: child.value.slice(last) })
  }
  node.children = out
}

function remarkHighlight() {
  const data = this.data()
  const toMarkdown = (data.toMarkdownExtensions ??= [])
  toMarkdown.push({
    handlers: {
      highlight(node, _parent, state, info) {
        const exit = state.enter('highlight')
        const value = state.containerPhrasing(node, { ...info, before: '=', after: '=' })
        exit()
        return '==' + value + '=='
      },
    },
  })
  return (tree) => splitHighlights(tree)
}

export const remarkHighlightPlugin = $remark('remarkHighlight', () => remarkHighlight)

export const highlightSchema = $markSchema('highlight', () => ({
  parseDOM: [{ tag: 'mark' }],
  toDOM: () => ['mark', 0],
  parseMarkdown: {
    match: (node) => node.type === 'highlight',
    runner: (state, node, markType) => {
      state.openMark(markType)
      state.next(node.children)
      state.closeMark(markType)
    },
  },
  toMarkdown: {
    match: (mark) => mark.type.name === 'highlight',
    runner: (state, mark) => {
      state.withMark(mark, 'highlight')
    },
  },
}))

export const toggleHighlightCommand = $command('ToggleHighlight', (ctx) => () => toggleMark(highlightSchema.type(ctx)))

export const highlightInputRule = $inputRule((ctx) => markRule(/(?:==)([^=]+)(?:==)$/, highlightSchema.type(ctx)))

export const highlightKeymap = $useKeymap('highlightKeymap', {
  ToggleHighlight: {
    shortcuts: 'Mod-Shift-h',
    command: (ctx) => {
      const commands = ctx.get(commandsCtx)
      return () => commands.call(toggleHighlightCommand.key)
    },
  },
})

export const highlight = [remarkHighlightPlugin, highlightSchema, toggleHighlightCommand, highlightInputRule, highlightKeymap].flat()
