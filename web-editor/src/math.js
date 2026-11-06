// 公式：$...$（行内）和 $$...$$（独立一行）
// - 读写：原样读进来、原样存回去（输出就是标准的 $...$ / $$...$$，和手打完全一致）
// - 显示：用 KaTeX 渲染；“价格 $5 和 $10”这种不算公式，照常显示文字
// - 编辑：双击公式（或选中后按回车）弹出小框改 LaTeX 原文，边改边预览
// - 输入：打 $x^2$ 自动变成公式；空行打 $$ 再回车，插入独立一行的公式

import remarkMath from 'remark-math'
import katex from 'katex'
import { $remark, $node, $view, $inputRule, $prose } from '@milkdown/kit/utils'
import { InputRule } from '@milkdown/kit/prose/inputrules'
import { Plugin, NodeSelection, TextSelection } from '@milkdown/kit/prose/state'
import { t } from './i18n.js'

export const remarkMathPlugin = $remark('remarkMath', () => remarkMath)

/** 把 LaTeX 渲染进一个元素；写错了也不报错，显示成红字 */
export function renderTeX(el, tex, displayMode) {
  try {
    katex.render(tex, el, { displayMode, throwOnError: false, errorColor: '#d14', strict: 'ignore', trust: false })
  } catch (e) {
    el.textContent = tex
  }
}

// ---------- 节点 ----------

// 行内公式 $...$
export const mathInline = $node('math_inline', () => ({
  group: 'inline',
  inline: true,
  atom: true,
  // literal：不算公式的 $...$（比如“$5 和 $”），照常显示文字，但原样写回
  attrs: { value: { default: '' }, literal: { default: false } },
  parseDOM: [{ tag: 'span[data-type="math_inline"]', getAttrs: (dom) => ({ value: dom.dataset.value }) }],
  toDOM: (node) => ['span', { 'data-type': 'math_inline', 'data-value': node.attrs.value }, node.attrs.value],
  parseMarkdown: {
    match: (node) => node.type === 'inlineMath',
    runner: (state, node, type) => {
      // Pandoc 规则：$ 里面紧挨着的不能是空格
      const literal = /^\s|\s$/.test(node.value)
      state.addNode(type, { value: node.value, literal })
    },
  },
  toMarkdown: {
    match: (node) => node.type.name === 'math_inline',
    runner: (state, node) => state.addNode('inlineMath', undefined, node.attrs.value),
  },
}))

// 独立一行的公式 $$...$$
export const mathBlock = $node('math_block', () => ({
  group: 'block',
  atom: true,
  attrs: { value: { default: '' } },
  parseDOM: [{ tag: 'div[data-type="math_block"]', getAttrs: (dom) => ({ value: dom.dataset.value }) }],
  toDOM: (node) => ['div', { 'data-type': 'math_block', 'data-value': node.attrs.value }, node.attrs.value],
  parseMarkdown: {
    match: (node) => node.type === 'math',
    runner: (state, node, type) => state.addNode(type, { value: node.value }),
  },
  toMarkdown: {
    match: (node) => node.type.name === 'math_block',
    runner: (state, node) => state.addNode('math', undefined, node.attrs.value),
  },
}))

// ---------- 显示 ----------

function makeView(display) {
  return (node, view, getPos) => {
    const dom = document.createElement(display ? 'div' : 'span')
    dom.className = display ? 'math-block' : 'math-inline'
    let current = node
    const draw = () => {
      dom.dataset.value = current.attrs.value
      if (current.attrs.literal) {
        dom.className = 'math-literal'
        dom.textContent = '$' + current.attrs.value + '$'
      } else if (!current.attrs.value.trim()) {
        dom.textContent = display ? t('双击输入公式', 'Double-click to enter a formula') : t('公式', 'formula')
        dom.classList.add('math-empty')
      } else {
        dom.classList.remove('math-empty')
        renderTeX(dom, current.attrs.value, display)
      }
    }
    draw()
    dom.addEventListener('dblclick', (e) => {
      if (current.attrs.literal) return
      e.preventDefault()
      openMathEditor(view, getPos())
    })
    return {
      dom,
      update(next) {
        if (next.type !== current.type) return false
        current = next
        draw()
        return true
      },
      selectNode() { dom.classList.add('math-selected') },
      deselectNode() { dom.classList.remove('math-selected') },
      ignoreMutation: () => true,
      stopEvent: (e) => e.type === 'dblclick',
    }
  }
}

export const mathInlineView = $view(mathInline, () => makeView(false))
export const mathBlockView = $view(mathBlock, () => makeView(true))

// ---------- 编辑小框 ----------

let activeEditor = null

/**
 * 在 pos 处的公式下面弹出编辑框。
 * placeholders：[{ start, end }]，模板里的“空”，先选中第一个，Tab 跳到下一个
 */
export function openMathEditor(view, pos, { placeholders = [], isNew = false } = {}) {
  closeMathEditor(true)
  const node = view.state.doc.nodeAt(pos)
  if (!node || !node.type.name.startsWith('math_')) return
  const display = node.type.name === 'math_block'
  const anchor = view.nodeDOM(pos)

  const box = document.createElement('div')
  box.className = 'math-editor'
  box.innerHTML = `
    <div class="math-editor-preview"></div>
    <textarea spellcheck="false" autocapitalize="off" autocomplete="off"></textarea>
    <div class="math-editor-hint">${display ? t('⌘回车', '⌘Return') : t('回车', 'Return')} ${t('确定', 'to confirm')} · Esc ${t('取消', 'to cancel')}${placeholders.length > 1 ? ' · Tab ' + t('下一个空', 'for next blank') : ''}</div>`
  document.body.appendChild(box)
  const input = box.querySelector('textarea')
  const preview = box.querySelector('.math-editor-preview')
  input.value = node.attrs.value
  input.rows = display ? Math.min(8, Math.max(2, node.attrs.value.split('\n').length + 1)) : 1

  // 空的位置：跟着用户的输入一起挪
  let spots = placeholders.map((p) => ({ ...p }))
  let spotIndex = 0
  let lastValue = input.value
  const selectSpot = (i) => {
    if (!spots.length) return
    spotIndex = (i + spots.length) % spots.length
    input.setSelectionRange(spots[spotIndex].start, spots[spotIndex].end)
  }

  const refresh = () => renderTeX(preview, input.value || '\\square', display)
  refresh()

  const place = () => {
    const rect = (anchor ?? view.dom).getBoundingClientRect()
    const width = Math.min(Math.max(rect.width, 320), window.innerWidth - 32)
    box.style.width = width + 'px'
    box.style.left = Math.max(16, Math.min(rect.left + window.scrollX, window.innerWidth - width - 16)) + 'px'
    box.style.top = rect.bottom + window.scrollY + 8 + 'px'
  }
  place()

  const finish = (commit) => {
    if (activeEditor !== state) return
    activeEditor = null
    document.removeEventListener('keydown', onEscape, true)
    box.remove()
    const current = view.state.doc.nodeAt(pos)
    if (!current || current.type !== node.type) return
    const value = input.value.trim() ? input.value : ''
    let tr = view.state.tr
    if (commit && value) {
      tr = tr.setNodeMarkup(pos, undefined, { ...current.attrs, value, literal: false })
    } else if ((commit && !value) || (!commit && isNew)) {
      tr = tr.delete(pos, pos + current.nodeSize) // 空公式、或者新插入后取消：删掉
    }
    const after = Math.min(tr.mapping.map(pos + current.nodeSize), tr.doc.content.size)
    tr = tr.setSelection(TextSelection.near(tr.doc.resolve(after)))
    view.dispatch(tr)
    view.focus()
  }

  input.addEventListener('input', () => {
    // 输入改变了长度：光标后面的空跟着挪
    const delta = input.value.length - lastValue.length
    // 改动发生的位置：插入时在光标前 delta 个字，删除时就在光标处
    const editAt = input.selectionStart - Math.max(delta, 0)
    spots = spots.map((s) => {
      if (s.start > editAt) return { start: Math.max(editAt, s.start + delta), end: Math.max(editAt, s.end + delta) } // 改动在这个空前面：整体挪
      if (s.end >= editAt) return { start: s.start, end: Math.max(s.start, s.end + delta) }                       // 改动在这个空里面：空变长或变短
      return s                                                                                                       // 改动在后面：不动
    })
    lastValue = input.value
    if (display) input.rows = Math.min(8, Math.max(2, input.value.split('\n').length + 1))
    refresh()
  })
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && (!display || e.metaKey) && !e.isComposing) { e.preventDefault(); finish(true) }
    else if (e.key === 'Tab' && spots.length) { e.preventDefault(); selectSpot(spotIndex + (e.shiftKey ? -1 : 1)) }
  })
  input.addEventListener('blur', () => setTimeout(() => finish(true), 0))
  // 点编辑框里的预览、提示：输入框不丢焦点（不然会被当成“点到外面”而关掉）
  box.addEventListener('mousedown', (e) => { if (e.target !== input) e.preventDefault() })
  // Esc 在整个页面上都有效
  function onEscape(e) {
    if (e.key !== 'Escape' || e.isComposing) return
    e.preventDefault()
    e.stopPropagation()
    finish(false)
  }
  document.addEventListener('keydown', onEscape, true)

  const state = { finish }
  activeEditor = state
  input.focus()
  if (spots.length) selectSpot(0)
  else input.setSelectionRange(input.value.length, input.value.length)
}

export function closeMathEditor(commit) {
  activeEditor?.finish(commit)
}

// ---------- 输入 ----------

// 打 $x^2$：最后一个 $ 打完就变成公式（$ 里面紧挨着的不能是空格，所以“$5 和 $”不会变）
export const mathInlineInputRule = $inputRule((ctx) =>
  new InputRule(/(?<![\\$])\$([^\s$](?:[^$\n]*[^\s$\\])?)\$$/, (state, match, start, end) => {
    const $start = state.doc.resolve(start)
    if ($start.parent.type.spec.code) return null
    if (state.schema.marks.inlineCode?.isInSet($start.marks())) return null
    return state.tr.replaceWith(start, end, mathInline.type(ctx).create({ value: match[1] }))
  }))

// 空行打 $$ 再回车：插入独立一行的公式并打开编辑框；选中公式按回车：编辑它
export const mathKeys = $prose((ctx) => new Plugin({
  props: {
    handleKeyDown(view, event) {
      if (event.key !== 'Enter' || event.shiftKey || event.metaKey || event.isComposing) return false
      const { selection } = view.state
      if (selection instanceof NodeSelection && selection.node.type.name.startsWith('math_') && !selection.node.attrs.literal) {
        openMathEditor(view, selection.from)
        return true
      }
      const { $from, empty } = selection
      if (!empty || $from.parent.type.name !== 'paragraph' || $from.parent.textContent.trim() !== '$$') return false
      const pos = $from.before()
      view.dispatch(view.state.tr.replaceWith(pos, pos + $from.parent.nodeSize, mathBlock.type(ctx).create({ value: '' })))
      setTimeout(() => openMathEditor(view, pos, { isNew: true }), 0)
      return true
    },
  },
}))

export const math = [remarkMathPlugin, mathInline, mathBlock, mathInlineView, mathBlockView, mathInlineInputRule, mathKeys].flat()
