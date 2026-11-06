// 用 # 写标题：打完 “# ” 不马上把 # 吃掉。
// - # 一直看得见，这一行已经按标题的样子显示（# 是淡色的）
// - 按回车、或者光标离开这一行，才变成真正的标题，# 才消失
// - 还没按回车就自动保存了也没关系：存进文件的就是标准的 “# 标题”
//
// 只认“刚刚打出来的” #：文件里本来就有的 \# 开头的普通文字（故意不当标题的），不会被改成标题。

import { $prose } from '@milkdown/kit/utils'
import { Plugin, PluginKey } from '@milkdown/kit/prose/state'
import { Decoration, DecorationSet } from '@milkdown/kit/prose/view'

const key = new PluginKey('pendingHeading')

/** 段落开头是 “# ” 加文字：返回 { level, prefixLen } */
export function headingPrefix(node) {
  if (!node || node.type.name !== 'paragraph') return null
  const m = /^(#{1,6})[  ]+(?=\S)/.exec(node.textContent)
  return m ? { level: m[1].length, prefixLen: m[0].length } : null
}

/** 把 pos 处的段落变成标题（去掉开头的 #） */
function convert(tr, pos) {
  const node = tr.doc.nodeAt(pos)
  const info = headingPrefix(node)
  if (!info) return tr
  const heading = tr.doc.type.schema.nodes.heading
  tr.delete(pos + 1, pos + 1 + info.prefixLen)
  return tr.setNodeMarkup(pos, heading, { ...heading.defaultAttrs, level: info.level })
}

/** 正在打的那个“待定标题”段落的位置（没有就是 null） */
const armedPos = (state) => key.getState(state)?.pos ?? null

/** 保存用：把待定标题当成真标题，生成要写进文件的文档（编辑器里不变） */
export function docForSave(state) {
  const pos = armedPos(state)
  return pos == null ? state.doc : convert(state.tr, pos).doc
}

export const pendingHeading = $prose(() => new Plugin({
  key,
  state: {
    init: () => ({ pos: null }),
    apply(tr, value, _old, state) {
      let pos = value.pos == null ? null : tr.mapping.map(value.pos)
      if (pos != null && !headingPrefix(state.doc.nodeAt(pos))) pos = null // # 被删掉了，或者已经变成标题
      if (tr.docChanged) {
        // 刚在段落开头打出了 “# ”（改动落在 # 那一段上）：开始等回车
        const { $from } = state.selection
        const info = headingPrefix($from.parent)
        if (info && $from.depth >= 1) {
          const p = $from.before()
          let touched = false
          tr.mapping.maps.forEach((map) => map.forEach((_a, _b, start, end) => {
            if (start <= p + 1 + info.prefixLen && end >= p + 1) touched = true
          }))
          if (touched) pos = p
        }
      }
      return { pos }
    },
  },
  // 光标离开了待定标题那一行：变成真正的标题
  appendTransaction(_trs, _old, state) {
    const pos = armedPos(state)
    if (pos == null) return null
    const node = state.doc.nodeAt(pos)
    const { from, to } = state.selection
    if (from >= pos && to <= pos + node.nodeSize) return null
    return convert(state.tr, pos)
  },
  props: {
    // 按回车：先变成标题，再照常换行
    handleKeyDown(view, event) {
      if (event.key !== 'Enter' || event.shiftKey || event.isComposing) return false
      const pos = armedPos(view.state)
      if (pos == null) return false
      const { $from } = view.state.selection
      if ($from.depth < 1 || $from.before() !== pos) return false
      view.dispatch(convert(view.state.tr, pos))
      return false // 让编辑器接着处理回车（在标题后面开一个新段落）
    },
    // 待定标题：整行按标题大小显示，# 淡一点
    decorations(state) {
      const pos = armedPos(state)
      if (pos == null) return null
      const node = state.doc.nodeAt(pos)
      const info = headingPrefix(node)
      if (!info) return null
      return DecorationSet.create(state.doc, [
        Decoration.node(pos, pos + node.nodeSize, { class: `pending-heading pending-h${info.level}` }),
        Decoration.inline(pos + 1, pos + 1 + info.prefixLen, { class: 'pending-hash' }),
      ])
    },
  },
}))
