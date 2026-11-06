// 分界线和拖选：
// 1. 点在分界线那一条（整行宽、上下留出的空白里）就选中它。
//    浏览器自己判断“点到哪了”时，分界线这种没有文字的东西经常判断成上一行或下一行的文字，
//    所以有时能选中有时不能。这里自己处理：点到 <hr> 上就直接选中它。
// 2. 拖选由编辑器自己处理（从文字、分界线、笔记下面的空白处开始都行）：
//    鼠标停在哪根分界线上，选区就正好到那根为止。
//    浏览器的选区只能停在文字里，好几根分界线连在一起时中间没有文字可停，结果要么全选上要么一根都没选上；
//    在浏览器拖选的过程中去纠正又会和浏览器来回抢，选区一闪一闪。所以干脆不用浏览器的拖选。
//    双击选词、三击选段、⇧+点、表格里拖选，还是交给浏览器和表格插件。
//    在蓝色的选中范围里按下（包括选中的分界线、行尾的蓝色）按住拖是把选中的内容拖走，也是自己处理。
// 3. 拖选一段时，夹在中间的分界线也显示成选中的颜色（浏览器只给文字涂选中色）。

import { Plugin, Selection, NodeSelection, TextSelection } from '@milkdown/kit/prose/state'
import { dropPoint } from '@milkdown/kit/prose/transform'
import { Decoration, DecorationSet } from '@milkdown/kit/prose/view'
import { $prose } from '@milkdown/kit/utils'

function hrPosOf(view, hr) {
  let found = null
  view.state.doc.descendants((node, pos) => {
    if (found != null) return false
    if (node.type.name === 'hr' && view.nodeDOM(pos) === hr) found = pos
  })
  return found
}

// 鼠标在 (x, y)：在某根分界线上（或两个块之间的空隙里、紧挨着分界线）吗？是的话返回那根分界线。
// 鼠标在文字那一行上时一律不算（不然拖选分界线下面那一行时，选区会被拽到分界线上）
function hrAt(view, x, y) {
  const el = document.elementFromPoint(x, y)
  const hit = el?.closest?.('hr')
  if (hit && view.dom.contains(hit)) return hit
  if (el !== view.dom) return null // 在文字、图片、表格……上
  // 两个块之间的空隙：上面或下面紧挨着的是分界线才算
  let best = null, bestDist = 8
  for (const hr of view.dom.querySelectorAll(':scope > hr')) {
    const r = hr.getBoundingClientRect()
    const dist = y < r.top ? r.top - y : y > r.bottom ? y - r.bottom : 0
    if (dist < bestDist) { best = hr; bestDist = dist }
  }
  return best
}

// 选区终点：从 anchor 拖到分界线 hrPos 上 → 往下拖就包括这根（停在它后面），往上拖也包括它（停在它前面）
function headAtDivider(doc, anchor, hrPos) {
  return hrPos >= anchor ? hrPos + doc.nodeAt(hrPos).nodeSize : hrPos
}

// 拖选时鼠标在 (x, y)，选区终点应该在哪
function headAt(view, anchor, x, y) {
  const hr = hrAt(view, x, y)
  const hrPos = hr && hrPosOf(view, hr)
  if (hrPos != null) return headAtDivider(view.state.doc, anchor, hrPos)
  const hit = view.posAtCoords({ left: x, top: y })
  if (hit) return hit.pos
  // 拖到编辑区上面 / 下面去了：算到开头 / 结尾
  const box = view.dom.getBoundingClientRect()
  if (y < box.top) return 0
  if (y > box.bottom) return view.state.doc.content.size
  return null
}

// 起点在分界线上：往下拖从它前面开始，往上拖从它后面开始，这样它自己也算在里面
function anchorFromDivider(doc, hrPos, head) {
  return head > hrPos ? hrPos : hrPos + doc.nodeAt(hrPos).nodeSize
}

// 从 anchor 开始自己处理拖选。anchor 也可以是函数：按鼠标大概在哪，决定起点（从分界线开始拖时用）
export function dragSelectFrom(view, anchorOrFn, event) {
  const startX = event.clientX, startY = event.clientY
  let last = event, moved = false
  const update = () => {
    const { doc } = view.state
    const rough = view.posAtCoords({ left: last.clientX, top: last.clientY })?.pos ?? (last.clientY < startY ? 0 : doc.content.size)
    const anchor = typeof anchorOrFn === 'function' ? anchorOrFn(rough) : anchorOrFn
    let head = headAt(view, anchor, last.clientX, last.clientY)
    if (head == null) return
    // 分界线之间、文章开头结尾这些地方放不了文字光标，选区端点会自动挪到最近的文字里，
    // 所以直接用 create（端点可以停在两块之间），删除、复制都按这个范围
    const sel = head === anchor ? TextSelection.create(doc, anchor) : TextSelection.create(doc, anchor, head)
    if (!sel.eq(view.state.selection)) view.dispatch(view.state.tr.setSelection(sel))
  }
  // 拖到窗口上下边缘：自动滚动
  const scroller = document.scrollingElement || document.documentElement
  const timer = setInterval(() => {
    if (!moved) return
    const edge = 28
    const dy = last.clientY < edge ? -14 : last.clientY > innerHeight - edge ? 14 : 0
    if (!dy) return
    scroller.scrollTop += dy
    update()
  }, 30)
  const move = (e) => {
    if (e.buttons !== 1) return up()
    last = e
    if (!moved && Math.abs(e.clientY - startY) < 3 && Math.abs(e.clientX - startX) < 3) return
    moved = true
    update()
  }
  const up = () => {
    clearInterval(timer)
    window.removeEventListener('mousemove', move)
    window.removeEventListener('mouseup', up)
  }
  window.addEventListener('mousemove', move)
  window.addEventListener('mouseup', up)
}

// (x, y) 在选中范围（看得见的蓝色部分）里吗：选中的文字、选中的分界线，
// 还有中间几行行尾右边、段落之间那些也涂成蓝色的地方
function inSelection(view, x, y) {
  const { selection } = view.state
  if (selection.empty || selection instanceof NodeSelection) return false
  const inside = (r) => x >= r.left && x <= r.right && y >= r.top && y <= r.bottom
  for (const hr of view.dom.querySelectorAll('hr.hr-in-selection')) if (inside(hr.getBoundingClientRect())) return true
  try {
    const start = view.domAtPos(selection.from), end = view.domAtPos(selection.to)
    const range = document.createRange()
    range.setStart(start.node, start.offset)
    range.setEnd(end.node, end.offset)
    for (const r of range.getClientRects()) if (inside(r)) return true
  } catch { /* 位置算不出来就按下面的办法判断 */ }
  // 点到的位置落在选区中间（不含两端）：也算
  const box = view.dom.getBoundingClientRect()
  if (x < box.left || x > box.right) return false
  const hit = view.posAtCoords({ left: x, top: y })
  return !!hit && hit.pos > selection.from && hit.pos < selection.to
}

// 按住选中的内容拖到别处：松手的地方插进去，原来的删掉（按住 ⌥ 是复制一份）。
// 不用浏览器自带的拖动：它允许拖动的地方和画出来的蓝色对不上，选得长了有些地方拖不动
function dragSelectionAway(view, event) {
  const sel = view.state.selection
  const slice = sel.content()
  const startX = event.clientX, startY = event.clientY
  let moved = false, drop = null, last = event
  const caret = document.createElement('div')
  caret.className = 'drop-caret'

  const update = () => {
    const hit = view.posAtCoords({ left: last.clientX, top: last.clientY })
    let pos = hit ? (dropPoint(view.state.doc, hit.pos, slice) ?? hit.pos) : null
    // 拖回选区自己里面：不动
    if (pos != null && pos > sel.from && pos < sel.to) pos = null
    drop = pos
    if (pos == null) { caret.remove(); return }
    const c = view.coordsAtPos(pos)
    Object.assign(caret.style, { left: `${c.left + scrollX - 1}px`, top: `${c.top + scrollY}px`, height: `${Math.max(c.bottom - c.top, 16)}px` })
    if (!caret.isConnected) document.body.append(caret)
  }
  const scroller = document.scrollingElement || document.documentElement
  const timer = setInterval(() => {
    if (!moved) return
    const dy = last.clientY < 28 ? -14 : last.clientY > innerHeight - 28 ? 14 : 0
    if (dy) { scroller.scrollTop += dy; update() }
  }, 30)
  const move = (e) => {
    if (e.buttons !== 1) return up(e)
    last = e
    if (!moved && Math.abs(e.clientX - startX) < 4 && Math.abs(e.clientY - startY) < 4) return
    if (!moved) { moved = true; document.body.classList.add('dragging-selection') }
    update()
  }
  const up = (e) => {
    clearInterval(timer)
    caret.remove()
    document.body.classList.remove('dragging-selection')
    window.removeEventListener('mousemove', move)
    window.removeEventListener('mouseup', up)
    window.removeEventListener('keydown', key, true)
    if (cancelled) return
    if (!moved) {
      // 只是点了一下：取消选中，光标放到点的地方
      const hit = view.posAtCoords({ left: startX, top: startY })
      if (hit) view.dispatch(view.state.tr.setSelection(Selection.near(view.state.doc.resolve(hit.pos))))
      return
    }
    if (drop == null) return
    // 下面照编辑器自己处理“拖放”的做法：先删原来的，再插到（删完之后的）松手位置，选中插进去的内容
    const tr = view.state.tr
    if (!(e?.altKey ?? last.altKey)) tr.deleteSelection()
    const pos = tr.mapping.map(drop)
    const isNode = slice.openStart === 0 && slice.openEnd === 0 && slice.content.childCount === 1
    const before = tr.doc
    if (isNode) tr.replaceRangeWith(pos, pos, slice.content.firstChild)
    else tr.replaceRange(pos, pos, slice)
    if (tr.doc.eq(before)) return
    let end = pos
    tr.mapping.maps[tr.mapping.maps.length - 1].forEach((_f, _t, _nf, newTo) => { end = newTo })
    const $pos = tr.doc.resolve(pos)
    const inserted = isNode && $pos.nodeAfter && NodeSelection.isSelectable($pos.nodeAfter)
      ? NodeSelection.create(tr.doc, pos)
      : TextSelection.between($pos, tr.doc.resolve(end))
    view.dispatch(tr.setSelection(inserted).scrollIntoView())
    view.focus()
  }
  // 拖的时候按 esc：取消
  let cancelled = false
  const key = (e) => { if (e.key === 'Escape') { cancelled = true; e.preventDefault(); up(e) } }
  window.addEventListener('mousemove', move)
  window.addEventListener('mouseup', up)
  window.addEventListener('keydown', key, true)
}

// 这次按下鼠标，要不要由我们自己处理拖选（不是的就交给浏览器 / 其他插件）
function ownsTextDrag(view, event) {
  if (event.button !== 0 || event.detail !== 1) return false // 双击、三击：浏览器选词选段
  if (event.shiftKey || event.metaKey || event.ctrlKey || event.altKey) return false
  const target = event.target
  if (!(target instanceof Element) || !view.dom.contains(target)) return false
  // 图片、公式、表格、待办的勾选框：各有各的处理
  if (target.closest('img, .math-inline, .math-block, table, [contenteditable="false"]')) return false
  return true
}

export const dividerClick = $prose(() => new Plugin({
  props: {
    handleDOMEvents: {
      mousedown(view, event) {
        if (event.button !== 0 || event.metaKey) return false
        // 在蓝色的选中范围里按下：按住拖是把选中的内容拖走，只点一下是取消选中
        if (event.detail === 1 && !event.shiftKey && !event.ctrlKey && view.dom.contains(event.target)
            && !event.target.closest?.('img, .math-inline, .math-block, table')
            && inSelection(view, event.clientX, event.clientY)) {
          event.preventDefault()
          view.focus()
          dragSelectionAway(view, event)
          return true
        }
        const hr = event.target.closest?.('hr')
        if (hr && view.dom.contains(hr)) {
          const hrPos = hrPosOf(view, hr)
          if (hrPos == null) return false
          event.preventDefault()
          view.focus()
          const { doc, selection } = view.state
          if (event.shiftKey && !selection.empty) {
            // ⇧+点分界线：把选区延长到这条分界线（包括它）
            view.dispatch(view.state.tr.setSelection(TextSelection.create(doc, selection.anchor, headAtDivider(doc, selection.anchor, hrPos))))
            return true
          }
          view.dispatch(view.state.tr.setSelection(NodeSelection.create(doc, hrPos)))
          dragSelectFrom(view, (rough) => anchorFromDivider(view.state.doc, hrPos, rough), event)
          return true
        }

        // 点在文字上：光标放过去；按住拖就自己选
        if (!ownsTextDrag(view, event)) return false
        const hit = view.posAtCoords({ left: event.clientX, top: event.clientY })
        if (!hit) return false
        event.preventDefault()
        view.focus()
        const $pos = view.state.doc.resolve(hit.pos)
        // 点在两块之间（比如分界线旁边的空隙）：放到最近的文字里
        const caret = $pos.parent.inlineContent ? TextSelection.create(view.state.doc, hit.pos) : TextSelection.near($pos)
        view.dispatch(view.state.tr.setSelection(caret).setMeta('pointer', true))
        dragSelectFrom(view, caret.head, event)
        return true
      },
    },
    // 选中的一段里有分界线：给它加上选中的颜色
    decorations(state) {
      const { selection, doc } = state
      if (selection.empty || selection instanceof NodeSelection) return null
      const decos = []
      doc.nodesBetween(selection.from, selection.to, (node, pos) => {
        if (node.type.name === 'hr' && pos >= selection.from && pos + node.nodeSize <= selection.to) {
          decos.push(Decoration.node(pos, pos + node.nodeSize, { class: 'hr-in-selection' }))
        }
      })
      return decos.length ? DecorationSet.create(doc, decos) : null
    },
  },
}))
