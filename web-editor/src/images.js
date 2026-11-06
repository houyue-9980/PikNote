// 拖图片进笔记、⌘V 粘贴截图：把图片数据交给 Swift 存进“这层书架/assets/”，存好后在原位置插入图片。
// 网页本身没法直接写文件，所以分两步：这里读出图片 → Swift 存文件并告诉我们相对路径 → 插入。

import { $prose, $view } from '@milkdown/kit/utils'
import { Plugin, NodeSelection } from '@milkdown/kit/prose/state'
import { imageSchema } from '@milkdown/kit/preset/commonmark'
import { t } from './i18n.js'

const pending = new Map() // 请求编号 → 要插入的位置
let nextId = 1

function send(message) {
  const handler = window.webkit?.messageHandlers?.piknote
  if (handler) handler.postMessage(message)
  else console.log('[to swift]', message.type, message.name)
}

const imageFiles = (list) => [...(list || [])].filter((f) => f.type.startsWith('image/'))

/** 文件 → base64（不带 data: 前缀） */
const toBase64 = (file) => new Promise((resolve, reject) => {
  const reader = new FileReader()
  reader.onload = () => resolve(String(reader.result).split(',')[1] || '')
  reader.onerror = () => reject(reader.error)
  reader.readAsDataURL(file)
})

const extensionFor = (type) => ({ 'image/jpeg': 'jpg', 'image/gif': 'gif', 'image/webp': 'webp', 'image/heic': 'heic', 'image/tiff': 'tiff' }[type] || 'png')

function screenshotName(type) {
  const d = new Date()
  const p = (n) => String(n).padStart(2, '0')
  const stamp = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}.${p(d.getMinutes())}.${p(d.getSeconds())}`
  return `${t('截图', 'Screenshot')} ${stamp}.${extensionFor(type)}`
}

/** 把几张图片交给 Swift 保存，按顺序插在 pos */
async function saveImages(files, pos, { pasted = false } = {}) {
  for (const file of files) {
    const id = nextId++
    pending.set(id, pos)
    // 粘贴的截图没有像样的名字（通常叫 image.png），自动起一个
    const name = pasted || !file.name || /^image\.\w+$/i.test(file.name) ? screenshotName(file.type) : file.name
    send({ type: 'saveImage', id, name, data: await toBase64(file) })
  }
}

/** Swift 存好了：在记下的位置插入图片（失败时 src 为空，就什么都不插） */
export function imageSaved(view, id, src, alt) {
  const pos = pending.get(id)
  pending.delete(id)
  if (pos == null || !src) return
  const { state } = view
  const at = Math.min(pos, state.doc.content.size)
  const node = state.schema.nodes.image.create({ src, alt: alt || '' })
  const tr = state.tr.insert(at, node)
  // 后面的图片排在这张后面
  for (const [k, p] of pending) if (p >= at) pending.set(k, p + node.nodeSize)
  view.dispatch(tr.scrollIntoView())
}

export const imageDropPaste = $prose(() => new Plugin({
  props: {
    handleDrop(view, event) {
      const files = imageFiles(event.dataTransfer?.files)
      if (!files.length) return false
      event.preventDefault()
      const pos = view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos ?? view.state.selection.from
      saveImages(files, pos)
      return true
    },
    handlePaste(view, event) {
      const items = [...(event.clipboardData?.items || [])]
      const files = items.filter((i) => i.kind === 'file' && i.type.startsWith('image/')).map((i) => i.getAsFile()).filter(Boolean)
      if (!files.length) return false
      event.preventDefault()
      const { from, to } = view.state.selection
      if (from !== to) view.dispatch(view.state.tr.deleteSelection())
      saveImages(files, view.state.selection.from, { pasted: true })
      return true
    },
  },
}))

// 拖文件经过编辑器时，明确告诉浏览器“这里可以放文件”，松手时才会收到 drop
document.addEventListener('dragover', (event) => {
  if ([...(event.dataTransfer?.types || [])].includes('Files')) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }
})

/** Mac 这边接住了拖进来的图片并存好：插在网页坐标 (x, y) 对应的位置 */
export function insertImagesAt(view, x, y, items) {
  const pos = view.posAtCoords({ left: x, top: y })?.pos ?? view.state.selection.from
  let tr = view.state.tr
  let at = Math.min(pos, tr.doc.content.size)
  for (const { src, alt } of items) {
    const node = view.state.schema.nodes.image.create({ src, alt: alt || '' })
    tr = tr.insert(at, node)
    at += node.nodeSize
  }
  view.dispatch(tr.scrollIntoView())
  view.focus()
}

// ---------- 图片大小：![说明|300](路径) ----------
// 宽度写在说明后面（Obsidian 的写法），文件还是纯 Markdown；
// 不认识这个写法的软件会按原图大小显示，不会乱。

/** "回归图|300" → { text: "回归图", width: 300 } */
export function splitAlt(alt) {
  const m = /^(.*?)\|(\d+)$/.exec(alt || '')
  return m ? { text: m[1], width: Number(m[2]) } : { text: alt || '', width: null }
}

export const imageView = $view(imageSchema.node, () => (node) => {
  const img = document.createElement('img')
  let current = node
  // 图片读不出来：不只显示一个名字，写清楚找的是哪个文件
  img.addEventListener('error', () => {
    img.classList.add('image-broken')
    img.alt = t(`⚠︎ 找不到图片：${current.attrs.src}`, `⚠︎ Image not found: ${current.attrs.src}`)
  })
  img.addEventListener('load', () => img.classList.remove('image-broken'))
  const draw = () => {
    const { text, width } = splitAlt(current.attrs.alt)
    img.classList.remove('image-broken')
    img.src = current.attrs.src
    img.alt = text
    if (current.attrs.title) img.title = current.attrs.title
    img.style.width = width ? width + 'px' : ''
  }
  draw()
  return {
    dom: img,
    update(next) {
      if (next.type !== current.type) return false
      current = next
      draw()
      return true
    },
    selectNode() { img.classList.add('image-selected') },
    deselectNode() { img.classList.remove('image-selected') },
  }
})

/** 现在选中的是不是图片 */
export function selectedImage(state) {
  const sel = state.selection
  return sel instanceof NodeSelection && sel.node.type.name === 'image' ? sel : null
}

/** 选中的图片放大 / 缩小 / 恢复原大小；没选中图片就返回 false */
export function resizeSelectedImage(view, direction) {
  const sel = selectedImage(view.state)
  if (!sel) return false
  const img = view.nodeDOM(sel.from)
  const { text, width } = splitAlt(sel.node.attrs.alt)
  const natural = img?.naturalWidth || width || 400
  const shown = width || Math.round(img?.getBoundingClientRect().width || natural)
  const maxWidth = Math.round(view.dom.getBoundingClientRect().width)
  let next = null
  if (direction === 'in') next = Math.min(Math.round(shown * 1.2), maxWidth)
  else if (direction === 'out') next = Math.max(Math.round(shown / 1.2), 40)
  // 恢复原大小，或者调回了原图宽度：不写宽度
  if (direction === 'reset' || (next != null && Math.abs(next - natural) < 4 && natural <= maxWidth)) next = null
  const alt = next ? `${text}|${next}` : text
  if (alt === sel.node.attrs.alt) return true
  let tr = view.state.tr.setNodeMarkup(sel.from, undefined, { ...sel.node.attrs, alt })
  tr = tr.setSelection(NodeSelection.create(tr.doc, sel.from)) // 保持选中，可以连续按
  view.dispatch(tr)
  return true
}
