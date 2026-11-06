// 拾记 PikNote 编辑器（跑在 WKWebView 里）
// Swift 外壳通过 window.piknote 调用这里的函数；这里通过 send() 给 Swift 发消息。
//
// 发给 Swift 的消息：
//   ready                编辑器页面准备好了
//   loaded               笔记内容已放进编辑器
//   changed  markdown    内容变了（Swift 负责停止输入 1 秒后保存）
//   outline  headings    大纲变了：[{ level, text }]
//   state    {...}       光标处的格式（工具栏按钮按下的样子）
//   openLink href        ⌘+点击了链接

import { Editor, rootCtx, defaultValueCtx, editorViewOptionsCtx, editorViewCtx, remarkStringifyOptionsCtx, commandsCtx, serializerCtx } from '@milkdown/kit/core'
import {
  commonmark, toggleStrongCommand, toggleEmphasisCommand, toggleInlineCodeCommand, turnIntoTextCommand,
  wrapInHeadingCommand, wrapInBulletListCommand, wrapInOrderedListCommand, wrapInBlockquoteCommand,
  createCodeBlockCommand, insertHrCommand, insertImageCommand, liftListItemCommand, remarkPreserveEmptyLinePlugin,
  wrapInHeadingInputRule,
} from '@milkdown/kit/preset/commonmark'
import { gfm, remarkGFMPlugin, toggleStrikethroughCommand, insertTableCommand, addRowAfterCommand, addColAfterCommand } from '@milkdown/kit/preset/gfm'
import { history } from '@milkdown/kit/plugin/history'
import { listener, listenerCtx } from '@milkdown/kit/plugin/listener'
import { getMarkdown, $prose, $remark } from '@milkdown/kit/utils'
import { Selection, TextSelection, Plugin } from '@milkdown/kit/prose/state'
import { lift } from '@milkdown/kit/prose/commands'
import { deleteRow, deleteColumn, deleteTable } from '@milkdown/kit/prose/tables'
import { math } from './math.js'
import { highlight, toggleHighlightCommand } from './highlight.js'
import { quickBarKeys, toggleQuickBar, insertFormula } from './quickbar.js'
import { setLang } from './i18n.js'
import { pendingHeading, docForSave } from './heading.js'
import { imageDropPaste, imageSaved, insertImagesAt, imageView, selectedImage, resizeSelectedImage } from './images.js'

let editor = null

// 不保留空行：Milkdown 默认会把空段落存成 <br />（HTML），文件就不是纯 Markdown 了。
// 去掉这个功能；文件里已有的单独一行 <br />，读进来时也去掉（下次编辑保存时就清理干净了）。
// 另外去掉“打完 # 和空格马上变标题”的规则，换成 heading.js 里等回车再变的版本
const commonmarkWithoutEmptyLines = commonmark.filter((plugin) => !remarkPreserveEmptyLinePlugin.includes(plugin) && plugin !== wrapInHeadingInputRule)
const dropBrLines = $remark('dropBrLines', () => () => (tree) => {
  const isBr = (node) => node.type === 'html' && /^<br\s*\/?>$/i.test(node.value.trim())
  const walk = (node) => {
    if (!node.children) return
    // 只去掉“单独占一行”的 <br />（解析出来是：只装着一个 <br /> 的段落，或者单独的 html 块）；
    // 段落中间的 <br> 是换行，不动；代码块里的不是 html 节点，也不会被碰到
    const onlyBr = (child) => isBr(child) || (child.type === 'paragraph' && child.children?.length === 1 && isBr(child.children[0]))
    node.children = node.children.filter((child) => !onlyBr(child))
    node.children.forEach((child) => { if (child.type !== 'paragraph') walk(child) })
  }
  walk(tree)
})

// 连续好几个空行合成一个（空段落留下的）；代码块和公式块里的空行有意义，不动
function collapseBlankLines(md) {
  const out = []
  let fence = null // 正在代码块里：记着开头的 ``` 或 ~~~；在公式块里：'$$'
  let blank = 0
  for (const line of md.split('\n')) {
    const trimmed = line.trim()
    if (fence) {
      out.push(line)
      if ((fence === '$$' && trimmed === '$$') || (fence !== '$$' && trimmed.startsWith(fence))) fence = null
      continue
    }
    const open = /^(`{3,}|~{3,})/.exec(trimmed)
    if (open) fence = open[1]
    else if (trimmed === '$$') fence = '$$'
    if (trimmed === '') {
      blank++
      if (blank > 1) continue
    } else blank = 0
    out.push(line)
  }
  return out.join('\n')
}

// 表格分隔行统一写成最常见的 | --- | :-: | 样子
function tidy(md) {
  md = collapseBlankLines(md)
  return md.replace(/^\|(?: *:?-+:? *\|)+ *$/gm, (row) =>
    '|' + row.slice(1, -1).split('|').map((cell) => {
      const c = cell.trim()
      const left = c.startsWith(':'), right = c.endsWith(':')
      return ' ' + (left ? ':' : '') + '---' + (right ? ':' : '') + ' '
    }).join('|') + '|')
}

// 把消息发给 Swift；在普通浏览器里调试时就打印到控制台
function send(message) {
  const handler = window.webkit?.messageHandlers?.piknote
  if (handler) handler.postMessage(message)
  else console.log('[to swift]', message)
}

const view = () => editor?.action((ctx) => ctx.get(editorViewCtx))

// ---------- 大纲和工具栏状态 ----------

function headingsOf(doc) {
  const list = []
  doc.descendants((node, pos) => {
    if (node.type.name === 'heading') list.push({ level: node.attrs.level, text: node.textContent, pos })
    return node.type.name !== 'heading' // 标题里面不用再找
  })
  return list
}

function stateOf(state) {
  const { $from, empty, from, to } = state.selection
  const markActive = (name) => {
    const type = state.schema.marks[name]
    if (!type) return false
    return empty ? !!type.isInSet(state.storedMarks || $from.marks()) : state.doc.rangeHasMark(from, to, type)
  }
  let block = 'paragraph'
  if ($from.parent.type.name === 'heading') block = 'h' + $from.parent.attrs.level
  else if ($from.parent.type.name === 'code_block') block = 'code'
  let list = null, quote = false, inTable = false
  for (let d = $from.depth; d > 0; d--) {
    const node = $from.node(d)
    const name = node.type.name
    if (name === 'list_item' && list == null) {
      list = node.attrs.checked != null ? 'task' : node.attrs.listType === 'ordered' ? 'ordered' : 'bullet'
    }
    if (name === 'blockquote') quote = true
    if (name === 'table') inTable = true
  }
  // 光标所在的是第几个标题下面（大纲里高亮这一项）
  let section = -1
  headingsOf(state.doc).forEach((h, i) => { if (h.pos <= from) section = i })
  return {
    section,
    imageSelected: !!selectedImage(state),
    bold: markActive('strong'), italic: markActive('emphasis'), strike: markActive('strike_through'),
    highlight: markActive('highlight'), code: markActive('inlineCode'), link: markActive('link'),
    block, list, quote, inTable,
  }
}

// 每次编辑或移动光标后，把有变化的大纲和格式状态告诉 Swift
let lastOutline = '', lastState = ''
function report(v, prev) {
  if (!prev || !v.state.doc.eq(prev.doc)) {
    const outline = JSON.stringify(headingsOf(v.state.doc).map(({ level, text }) => ({ level, text })))
    if (outline !== lastOutline) { lastOutline = outline; send({ type: 'outline', headings: JSON.parse(outline) }) }
  }
  const s = JSON.stringify(stateOf(v.state))
  if (s !== lastState) { lastState = s; send({ type: 'state', state: JSON.parse(s) }) }
}
const reporter = $prose(() => new Plugin({
  view: (v) => {
    report(v) // 刚打开时也报一次
    return { update: report }
  },
}))

// ---------- 打开笔记 ----------

async function load(markdown) {
  if (editor) await editor.destroy()
  const root = document.getElementById('editor')
  root.innerHTML = ''
  lastOutline = ''
  lastState = ''

  editor = await Editor.make()
    .config((ctx) => {
      ctx.set(rootCtx, root)
      ctx.set(defaultValueCtx, markdown)
      // 存回文件时的写法偏好：列表用 -（最常见的写法），尽量少改用户的文件
      ctx.update(remarkStringifyOptionsCtx, (prev) => ({ ...prev, bullet: '-', bulletOther: '*', rule: '-' }))
      // 表格不按列宽重新对齐（中文宽度算不准，对齐反而乱，还会改动整张表）
      ctx.set(remarkGFMPlugin.options.key, { tablePipeAlign: false })
      ctx.update(editorViewOptionsCtx, (prev) => ({ ...prev, attributes: { spellcheck: 'false' } }))
      // 用户改了内容才通知外壳；外壳负责“停止输入 1 秒后保存”
      ctx.get(listenerCtx).markdownUpdated((c, md, prevMd) => {
        // 存进文件时，还在打的 “# 标题” 也按真正的标题存
        if (md !== prevMd) send({ type: 'changed', markdown: tidy(c.get(serializerCtx)(docForSave(c.get(editorViewCtx).state))) })
      })
    })
    .use(commonmarkWithoutEmptyLines)
    .use(dropBrLines)
    .use(gfm)
    .use(history)
    .use(listener)
    .use(math)
    .use(quickBarKeys)
    .use(pendingHeading)
    .use(imageDropPaste)
    .use(imageView)
    .use(highlight)
    .use(reporter)
    .create()

  send({ type: 'loaded' })
}

// 打开后让光标进到编辑器：新笔记（只有一个标题）放到末尾接着写，其他笔记放在开头
function focusEditor() {
  const v = view()
  if (!v) return
  const short = v.state.doc.childCount <= 1
  const sel = short ? Selection.atEnd(v.state.doc) : Selection.atStart(v.state.doc)
  v.dispatch(v.state.tr.setSelection(sel))
  v.focus()
}

// 图片等相对路径以笔记所在的文件夹为准
function setBase(href) {
  let base = document.querySelector('base')
  if (!base) { base = document.createElement('base'); document.head.prepend(base) }
  base.href = href
}

// ---------- 工具栏命令 ----------

function call(command, payload) {
  editor?.action((ctx) => ctx.get(commandsCtx).call(command.key, payload))
}

function run(pmCommand) {
  const v = view()
  if (v) pmCommand(v.state, v.dispatch)
}

function toggleTaskList() {
  const v = view()
  if (!v) return
  const current = stateOf(v.state)
  if (current.list == null) call(wrapInBulletListCommand)
  const { state } = view()
  const { $from } = state.selection
  for (let d = $from.depth; d > 0; d--) {
    const node = $from.node(d)
    if (node.type.name === 'list_item') {
      // 已经是待办 → 变回普通列表；否则 → 变成没勾的待办
      const checked = current.list === 'task' ? null : false
      view().dispatch(state.tr.setNodeMarkup($from.before(d), undefined, { ...node.attrs, checked }))
      return
    }
  }
}

function toggleList(kind, command) {
  const v = view()
  if (stateOf(v.state).list === kind) call(liftListItemCommand) // 再点一次取消列表
  else call(command)
}

function toggleLink(href) {
  const v = view()
  if (!v) return
  const type = v.state.schema.marks.link
  const { from, to, empty } = v.state.selection
  if (stateOf(v.state).link && !href) {
    // 去掉链接：把光标所在的整段链接都去掉
    const $pos = v.state.doc.resolve(from)
    const start = from - $pos.textOffset
    const node = $pos.parent.maybeChild($pos.index())
    const end = node ? start + node.nodeSize : to
    v.dispatch(v.state.tr.removeMark(empty ? start : from, empty ? end : to, type))
  } else if (href) {
    if (empty) {
      // 没选中文字：直接插入一个以网址为文字的链接
      v.dispatch(v.state.tr.insert(from, v.state.schema.text(href, [type.create({ href })])))
    } else {
      v.dispatch(v.state.tr.addMark(from, to, type.create({ href })))
    }
  }
  v.focus()
}

// 插入表格（行数包括表头那一行）：不设对齐（存成最常见的 | --- |），光标放进第一格
function insertTable(size) {
  const row = Math.max(2, Math.min(20, size?.row ?? 3))
  const col = Math.max(1, Math.min(20, size?.col ?? 3))
  const from = view().state.selection.from
  call(insertTableCommand, { row, col })
  const v = view()
  let tablePos = null
  v.state.doc.descendants((node, pos) => {
    if (tablePos != null) return false
    if (node.type.name === 'table' && pos + node.nodeSize > from) { tablePos = pos; return false }
  })
  if (tablePos == null) return
  let tr = v.state.tr
  tr.doc.nodeAt(tablePos).descendants((node, pos) => {
    if ('alignment' in node.attrs) tr = tr.setNodeMarkup(tablePos + 1 + pos, undefined, { ...node.attrs, alignment: null })
  })
  tr = tr.setSelection(Selection.findFrom(tr.doc.resolve(tablePos + 1), 1))
  v.dispatch(tr)
}

const commands = {
  bold: () => call(toggleStrongCommand),
  italic: () => call(toggleEmphasisCommand),
  strike: () => call(toggleStrikethroughCommand),
  highlight: () => call(toggleHighlightCommand),
  code: () => call(toggleInlineCodeCommand),
  paragraph: () => call(turnIntoTextCommand),
  heading: (level) => call(wrapInHeadingCommand, level),
  bulletList: () => toggleList('bullet', wrapInBulletListCommand),
  orderedList: () => toggleList('ordered', wrapInOrderedListCommand),
  taskList: toggleTaskList,
  quote: () => (stateOf(view().state).quote ? run(lift) : call(wrapInBlockquoteCommand)),
  codeBlock: () => call(createCodeBlockCommand),
  hr: () => call(insertHrCommand),
  link: toggleLink,
  image: ({ src, alt }) => call(insertImageCommand, { src, alt }),
  table: insertTable,
  addRow: () => call(addRowAfterCommand),
  addColumn: () => call(addColAfterCommand),
  deleteRow: () => run(deleteRow),
  deleteColumn: () => run(deleteColumn),
  deleteTable: () => run(deleteTable),
  formulaBar: () => toggleQuickBar(view()),
  imageSize: (direction) => resizeSelectedImage(view(), direction),
}

function command(name, arg) {
  const fn = commands[name]
  if (!fn) return console.warn('unknown command', name)
  if (name !== 'formulaBar') view()?.focus()
  fn(arg)
}

// 点大纲：跳到第 i 个标题
function scrollToHeading(i) {
  const v = view()
  const heading = v && headingsOf(v.state.doc)[i]
  if (!heading) return
  v.dispatch(v.state.tr.setSelection(TextSelection.create(v.state.doc, heading.pos + 1)))
  v.nodeDOM(heading.pos)?.scrollIntoView({ block: 'start', behavior: 'smooth' })
  v.focus()
}

// ---------- 鼠标 ----------

document.addEventListener('mousedown', (event) => {
  // 点待办前面的 ☐ / ☑ 就勾选或取消
  const li = event.target.closest?.('li[data-item-type="task"]')
  if (li && editor) {
    // 只认点在勾选框上（文字左边那一小块），点文字还是正常编辑
    const text = li.querySelector(':scope > p')
    if (!text || event.clientX >= text.getBoundingClientRect().left) return
    event.preventDefault()
    const v = view()
    const pos = v.posAtDOM(li, 0) - 1
    const node = v.state.doc.nodeAt(pos)
    if (!node || node.attrs.checked == null) return
    v.dispatch(v.state.tr.setNodeMarkup(pos, undefined, { ...node.attrs, checked: !node.attrs.checked }))
  }
})

// ⌘+点击链接：交给 Swift 打开（其他笔记 / PDF 开新窗口，网址用浏览器）
document.addEventListener('click', (event) => {
  const a = event.target.closest?.('a[href]')
  if (!a) return
  event.preventDefault()
  if (event.metaKey) send({ type: 'openLink', href: a.getAttribute('href') })
}, true)

window.piknote = {
  load,
  // Swift 存好拖进来 / 粘贴的图片后调用
  imageSaved: (id, src, alt) => imageSaved(view(), id, src, alt),
  // Mac 这边接住拖进来的图片后调用
  insertImagesAt: (x, y, items) => insertImagesAt(view(), x, y, items),
  setLang,
  // 换主题：light / dark / sepia
  setTheme: (theme) => { document.documentElement.dataset.theme = theme },
  // 个性化：正文字体和行间距；font 为空 = 系统默认
  setTypography: ({ font, lineHeight, paragraphSpacing } = {}) => {
    const root = document.documentElement.style
    if (paragraphSpacing != null) root.setProperty('--para-gap', String(paragraphSpacing))
    else root.removeProperty('--para-gap')
    if (font) root.setProperty('--body-font', `"${font.replace(/"/g, '')}", -apple-system, "PingFang SC", sans-serif`)
    else root.removeProperty('--body-font')
    if (lineHeight) root.setProperty('--line-height', String(lineHeight))
    else root.removeProperty('--line-height')
  },
  // 个性化：标题 1–5 的颜色，{ "1": "#C0392B", … }；没给的级别用主题默认颜色
  setHeadingColors: (colors) => {
    // "0" 是页面底色
    if (colors?.['0']) document.documentElement.style.setProperty('--bg', colors['0'])
    else document.documentElement.style.removeProperty('--bg')
    for (let level = 1; level <= 5; level++) {
      const c = colors?.[String(level)]
      if (c) document.documentElement.style.setProperty(`--h${level}-color`, c)
      else document.documentElement.style.removeProperty(`--h${level}-color`)
    }
  },
  // 测试用：直接插入一个公式
  insertFormula: (text, mode, placeholders) => insertFormula(view(), text, mode, placeholders),
  focusEditor,
  setBase,
  command,
  scrollToHeading,
  getMarkdown: () => editor ? tidy(editor.action((ctx) => ctx.get(serializerCtx)(docForSave(ctx.get(editorViewCtx).state)))) : '',
  // 调试用：拿到编辑器内部的视图
  view,
}

send({ type: 'ready' })
