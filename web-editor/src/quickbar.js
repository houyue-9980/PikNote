// 公式快捷栏：⌘⇧M 弹出，用中文、英文或拼音搜公式，↑↓ 选择，回车插入。
// 插入后光标停在第一个空，Tab 跳到下一个。输出就是标准的 $...$ / $$...$$。

import { $prose } from '@milkdown/kit/utils'
import { Plugin } from '@milkdown/kit/prose/state'
import { renderTeX, openMathEditor } from './math.js'
import { searchFormulas, expandTemplate, previewTeX } from './formulas.js'
import { t, isEnglish } from './i18n.js'

const MODE_KEY = 'piknote.formulaMode'
const loadMode = () => { try { return localStorage.getItem(MODE_KEY) || 'inline' } catch { return 'inline' } }
const saveMode = (m) => { try { localStorage.setItem(MODE_KEY, m) } catch {} }

let bar = null

export function toggleQuickBar(view) {
  if (bar) closeQuickBar()
  else openQuickBar(view)
}

export function closeQuickBar(refocus = true) {
  if (!bar) return
  const { root, view, onKey } = bar
  bar = null
  document.removeEventListener('keydown', onKey, true)
  root.remove()
  if (refocus) view.focus()
}

export function openQuickBar(view) {
  closeQuickBar(false)
  const root = document.createElement('div')
  root.className = 'qb-backdrop'
  root.innerHTML = `
    <div class="qb" role="dialog" aria-label="${t('公式快捷栏', 'Formula Bar')}">
      <div class="qb-head">
        <span class="qb-fx">fx</span>
        <input class="qb-input" placeholder="${t('搜索公式，比如：定积分、matrix、fangcha', 'Search formulas, e.g. integral, matrix, 方差')}" spellcheck="false" autocomplete="off">
        <span class="qb-tip">${t('中文、英文、拼音都能搜', 'English, Chinese, or pinyin')}</span>
      </div>
      <div class="qb-body">
        <div class="qb-list-wrap">
          <div class="qb-list"></div>
          <div class="qb-raw-tip">${t('找不到？直接输入 LaTeX 也可以', 'Not here? Type LaTeX directly.')}</div>
        </div>
        <div class="qb-side">
          <div class="qb-label">${t('预览', 'Preview')}</div>
          <div class="qb-preview"></div>
          <div class="qb-label">LaTeX</div>
          <div class="qb-code"></div>
          <div class="qb-note">${t('插入后光标停在高亮的位置，按 Tab 跳到下一个空', 'After inserting, the cursor starts at the highlighted blank. Press Tab for the next one.')}</div>
          <div class="qb-mode">
            <span class="qb-label">${t('插入为', 'Insert as')}</span>
            <div class="qb-seg">
              <button data-mode="inline">${t('行内公式', 'Inline')}</button><button data-mode="block">${t('独立一行', 'Display')}</button>
            </div>
          </div>
        </div>
      </div>
      <div class="qb-foot">
        <span><kbd>↑</kbd><kbd>↓</kbd> ${t('选择', 'Select')}</span>
        <span><kbd>↵</kbd> ${t('插入', 'Insert')}</span>
        <span><kbd>Tab</kbd> ${t('下一个空', 'Next blank')}</span>
        <span><kbd>⌘⇧M</kbd> ${t('打开 / 关闭', 'Open / Close')}</span>
        <span class="qb-spacer"></span>
        <span><kbd>esc</kbd> ${t('取消', 'Cancel')}</span>
      </div>
    </div>`
  document.body.appendChild(root)

  const input = root.querySelector('.qb-input')
  const list = root.querySelector('.qb-list')
  const preview = root.querySelector('.qb-preview')
  const code = root.querySelector('.qb-code')
  const note = root.querySelector('.qb-note')
  const segButtons = [...root.querySelectorAll('.qb-seg button')]
  let mode = loadMode()
  let results = []
  let selected = 0

  const setMode = (m) => {
    mode = m
    saveMode(m)
    segButtons.forEach((b) => b.classList.toggle('on', b.dataset.mode === m))
    showSelected()
  }

  // 一条结果：{ entry } 来自公式库；{ raw } 是用户直接输入的 LaTeX
  const search = () => {
    const q = input.value
    results = searchFormulas(q).map((entry) => ({ entry }))
    const looksLikeTeX = /[\\^_{}]/.test(q)
    if (q.trim() && (looksLikeTeX || !results.length)) results.unshift({ raw: q.trim() })
    selected = 0
    list.innerHTML = ''
    results.forEach((r, i) => {
      const row = document.createElement('div')
      row.className = 'qb-item'
      const formula = document.createElement('div')
      formula.className = 'qb-item-tex'
      renderTeX(formula, r.entry ? expandTemplate(r.entry.tpl).text : r.raw, false)
      const text = document.createElement('div')
      text.className = 'qb-item-text'
      text.innerHTML = r.entry
        ? `<div class="qb-zh"></div><div class="qb-en"></div>`
        : `<div class="qb-zh">${t('直接插入', 'Insert as typed')}</div><div class="qb-en">${t('你输入的 LaTeX', 'Your LaTeX')}</div>`
      if (r.entry) {
        // 英文界面：英文名在上、中文名在下；中文界面：中文名在上、英文名和拼音在下
        text.querySelector('.qb-zh').textContent = isEnglish() ? r.entry.en : r.entry.zh
        text.querySelector('.qb-en').textContent = isEnglish() ? r.entry.zh : `${r.entry.en} · ${r.entry.py.replace(/\s+/g, '')}`
      }
      row.append(formula, text)
      row.addEventListener('mousedown', (e) => { e.preventDefault(); select(i) })
      row.addEventListener('dblclick', () => insert())
      list.appendChild(row)
    })
    if (!results.length) list.innerHTML = `<div class="qb-empty">${t('没有找到，换个说法试试', 'No matches. Try other words.')}</div>`
    showSelected()
  }

  const select = (i) => {
    if (!results.length) return
    selected = (i + results.length) % results.length
    showSelected()
  }

  const showSelected = () => {
    ;[...list.children].forEach((el, i) => el.classList?.toggle('on', i === selected))
    list.children[selected]?.scrollIntoView?.({ block: 'nearest' })
    const r = results[selected]
    if (!r) { preview.innerHTML = ''; code.textContent = ''; return }
    renderTeX(preview, r.entry ? previewTeX(r.entry.tpl) : r.raw, true)
    // LaTeX 原文，第一个空高亮
    code.innerHTML = ''
    if (r.entry) {
      const { text, placeholders } = expandTemplate(r.entry.tpl)
      const first = placeholders[0]
      if (first) {
        const mark = document.createElement('mark')
        mark.textContent = text.slice(first.start, first.end)
        code.append(text.slice(0, first.start), mark, text.slice(first.end))
      } else code.textContent = text
      note.style.visibility = placeholders.length ? 'visible' : 'hidden'
    } else {
      code.textContent = r.raw
      note.style.visibility = 'hidden'
    }
  }

  const insert = () => {
    const r = results[selected]
    if (!r) return
    const { text, placeholders } = r.entry ? expandTemplate(r.entry.tpl) : { text: r.raw, placeholders: [] }
    closeQuickBar(false)
    insertFormula(view, text, mode, placeholders)
  }

  input.addEventListener('input', search)
  // 快捷栏开着时，按键在整个页面上都有效（不管刚才点了哪里）
  const onKey = (e) => {
    if (e.isComposing) return // 正在用拼音输入法打字
    const handled = () => { e.preventDefault(); e.stopPropagation() }
    if (e.key === 'Escape') { handled(); closeQuickBar() }
    else if (e.key.toLowerCase() === 'm' && e.metaKey && e.shiftKey) { handled(); closeQuickBar() }
    else if (e.key === 'ArrowDown') { handled(); select(selected + 1) }
    else if (e.key === 'ArrowUp') { handled(); select(selected - 1) }
    else if (e.key === 'Enter') { handled(); insert() }
    else if (document.activeElement !== input && e.key.length === 1 && !e.metaKey && !e.ctrlKey) input.focus() // 直接打字也进搜索框
  }
  document.addEventListener('keydown', onKey, true)
  segButtons.forEach((b) => b.addEventListener('mousedown', (e) => { e.preventDefault(); setMode(b.dataset.mode) }))
  root.addEventListener('mousedown', (e) => {
    if (e.target === input) return
    e.preventDefault() // 点面板里别的地方（预览、说明…）：搜索框不丢焦点
    if (e.target === root) closeQuickBar() // 点面板外面：关掉
  })

  bar = { root, view, onKey }
  setMode(mode)
  search()
  input.focus()
}

/** 在光标处插入公式，然后打开编辑框，光标停在第一个空 */
export function insertFormula(view, text, mode, placeholders = []) {
  const { schema } = view.state
  let tr = view.state.tr
  let pos
  if (mode === 'block') {
    const node = schema.nodes.math_block.create({ value: text })
    const { $from } = tr.selection
    if ($from.depth >= 1 && $from.parent.type.name === 'paragraph' && $from.parent.content.size === 0) {
      // 在空行上：直接把这行换成公式
      pos = $from.before()
      tr = tr.replaceWith(pos, $from.after(), node)
    } else {
      // 在有字的行上：插到这一段的后面
      pos = $from.depth >= 1 ? $from.after(1) : $from.pos
      tr = tr.insert(pos, node)
    }
  } else {
    pos = tr.selection.from
    tr = tr.replaceSelectionWith(schema.nodes.math_inline.create({ value: text }), false)
  }
  view.dispatch(tr)
  openMathEditor(view, pos, { placeholders })
}

// ⌘⇧M：打开 / 关闭快捷栏
export const quickBarKeys = $prose(() => new Plugin({
  props: {
    handleKeyDown(view, event) {
      if (event.metaKey && event.shiftKey && event.key.toLowerCase() === 'm') {
        event.preventDefault()
        toggleQuickBar(view)
        return true
      }
      return false
    },
  },
}))
