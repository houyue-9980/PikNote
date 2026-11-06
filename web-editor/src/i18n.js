// 编辑器里的界面文字：t('中文', 'English')，语言由 Swift 外壳通过 piknote.setLang 告诉我们
let lang = 'zh'
export const setLang = (value) => { lang = value === 'en' ? 'en' : 'zh' }
export const isEnglish = () => lang === 'en'
export const t = (zh, en) => (lang === 'en' ? en : zh)
