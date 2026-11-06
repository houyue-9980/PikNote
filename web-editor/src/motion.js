// 弹出框的进场 / 退场动画：靠 CSS 过渡（index.html 里的 .pk-enter / .pk-leave）。
// 系统设置里要求减弱动态效果时，直接出现、直接消失。

export const reducedMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches

/** 刚放进页面的元素：先处在“进场前”的样子，马上再变成正常样子，中间由 CSS 过渡 */
export function animateIn(el) {
  if (reducedMotion()) return
  el.classList.add('pk-enter')
  void el.offsetWidth // 让浏览器先按“进场前”的样子算一遍，再去掉，过渡才会播放
  el.classList.remove('pk-enter')
}

/** 退场：变成“退场后”的样子，过渡完再从页面上拿掉（最多等 300 毫秒） */
export function animateOut(el) {
  if (reducedMotion()) { el.remove(); return }
  el.classList.remove('pk-enter')
  el.classList.add('pk-leave')
  el.style.pointerEvents = 'none' // 退场中的框不再挡鼠标
  let done = false
  const finish = () => { if (!done) { done = true; el.remove() } }
  el.addEventListener('transitionend', finish, { once: true })
  setTimeout(finish, 300)
}
