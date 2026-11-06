// 表格：选中整行 / 整列 / 整张表后，按 delete 或 ⌘X 直接删掉这些行列（或整张表），
// 不用再去工具栏点。只选了几个格子（不是整行整列）时，还是原来的样子：清空格子里的字。
//
// Markdown 表格的规矩：第一行是表头，下面至少还要有一行。删行时会照顾这一点：
// 删掉表头 → 剩下的第一行变成表头；只剩表头 → 补一行空的；全删了 → 整张表删掉。

import { Plugin, Selection } from '@milkdown/kit/prose/state'
import { Fragment } from '@milkdown/kit/prose/model'
import { CellSelection, TableMap, selectedRect, isInTable } from '@milkdown/kit/prose/tables'
import { $prose } from '@milkdown/kit/utils'

// 选中的是整行 / 整列 / 整张表吗？是的话返回要删哪些
function wholeLines(selection) {
  if (!(selection instanceof CellSelection)) return null
  const rows = selection.isRowSelection(), cols = selection.isColSelection()
  if (!rows && !cols) return null
  const $cell = selection.$anchorCell
  const table = $cell.node(-1), tableStart = $cell.start(-1)
  const rect = TableMap.get(table).rectBetween(selection.$anchorCell.pos - tableStart, selection.$headCell.pos - tableStart)
  if (rows && cols) return { tablePos: tableStart - 1, kind: 'table' }
  return rows
    ? { tablePos: tableStart - 1, kind: 'rows', from: rect.top, to: rect.bottom }
    : { tablePos: tableStart - 1, kind: 'cols', from: rect.left, to: rect.right }
}

// 光标放进新表格第 row 行第 col 列的格子里
function cursorInCell(tr, tablePos, row, col) {
  const table = tr.doc.nodeAt(tablePos)
  const map = TableMap.get(table)
  const cellPos = tablePos + 1 + map.positionAt(Math.min(row, map.height - 1), Math.min(col, map.width - 1), table)
  return tr.setSelection(Selection.near(tr.doc.resolve(cellPos + 1)))
}

// 删掉整张表，原地留一个空段落放光标
function removeTable(tr, tablePos) {
  const table = tr.doc.nodeAt(tablePos)
  tr.replaceWith(tablePos, tablePos + table.nodeSize, tr.doc.type.schema.nodes.paragraph.create())
  return tr.setSelection(Selection.near(tr.doc.resolve(tablePos + 1)))
}

// 按 wholeLines() 的结果删行 / 删列 / 删表，返回 tr
function removeLines(tr, { tablePos, kind, from, to }) {
  const table = tr.doc.nodeAt(tablePos)
  if (!table || table.type.name !== 'table') return tr
  const { nodes } = tr.doc.type.schema
  const map = TableMap.get(table)
  const total = kind === 'cols' ? map.width : map.height
  if (kind === 'table' || (from === 0 && to >= total)) return removeTable(tr, tablePos)

  // 把一行改成表头行或普通行（格子里的内容和对齐方式不变）
  const asRow = (row, header) => (header ? nodes.table_header_row : nodes.table_row).create(row.attrs,
    row.content.content.map((cell) => (header ? nodes.table_header : nodes.table_cell).create(cell.attrs, cell.content)))

  let rows = []
  table.forEach((row, _, i) => {
    if (kind === 'rows') { if (i < from || i >= to) rows.push(row) }
    else rows.push(row.copy(Fragment.fromArray(row.content.content.filter((_, c) => c < from || c >= to))))
  })
  rows = rows.map((row, i) => asRow(row, i === 0))
  // 只剩表头：补一行空的
  if (rows.length === 1) {
    const width = rows[0].childCount
    rows.push(nodes.table_row.create(null, Array.from({ length: width }, () => nodes.table_cell.createAndFill())))
  }
  tr.replaceWith(tablePos, tablePos + table.nodeSize, table.type.create(table.attrs, rows))
  return kind === 'rows' ? cursorInCell(tr, tablePos, from, 0) : cursorInCell(tr, tablePos, 0, from)
}

// 工具栏的“删除行 / 删除列”也走这里（原来的命令删表头那一行会出错）
export function deleteTableLines(kind) {
  return (state, dispatch) => {
    if (!isInTable(state)) return false
    const rect = selectedRect(state)
    const info = kind === 'rows'
      ? { tablePos: rect.tableStart - 1, kind, from: rect.top, to: rect.bottom }
      : { tablePos: rect.tableStart - 1, kind, from: rect.left, to: rect.right }
    if (dispatch) dispatch(removeLines(state.tr, info).scrollIntoView())
    return true
  }
}

const deleteKeys = new Set(['Backspace', 'Delete'])

export const tableDelete = $prose(() => new Plugin({
  props: {
    // 选中整行 / 整列 / 整张表时按 delete：删掉它们
    handleKeyDown(view, event) {
      if (!deleteKeys.has(event.key) || event.altKey || event.shiftKey) return false
      const info = wholeLines(view.state.selection)
      if (!info) return false
      view.dispatch(removeLines(view.state.tr, info).scrollIntoView())
      return true
    },
  },
  // ⌘X 剪切：复制照常（剪贴板里就是选中的行列 / 表格），
  // 编辑器原本只会把格子清空，这里接着把清空的行列 / 表格删掉
  appendTransaction(trs, oldState, newState) {
    if (!trs.some((tr) => tr.getMeta('uiEvent') === 'cut')) return null
    const info = wholeLines(oldState.selection)
    if (!info) return null
    let tablePos = info.tablePos
    for (const tr of trs) tablePos = tr.mapping.map(tablePos)
    if (newState.doc.nodeAt(tablePos)?.type.name !== 'table') return null
    return removeLines(newState.tr, { ...info, tablePos })
  },
}))
