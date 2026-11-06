// 公式库：每条有中文名、英文名、拼音、别名和带“空”的模板。
// 模板里 #{…} 是一个“空”：插入后先选中第一个空，Tab 跳到下一个。
// 第一版：微积分、线性代数、概率统计，外加几个常用基础写法。

export const formulas = [
  // 基础
  { zh: '分数', en: 'fraction', py: 'fen shu', alias: ['除', 'frac'], tpl: '\\frac{#{a}}{#{b}}' },
  { zh: '根号', en: 'square root', py: 'gen hao', alias: ['平方根', 'sqrt'], tpl: '\\sqrt{#{x}}' },
  { zh: 'n 次根号', en: 'nth root', py: 'n ci gen hao', alias: ['开方'], tpl: '\\sqrt[#{n}]{#{x}}' },
  { zh: '上标', en: 'superscript', py: 'shang biao', alias: ['次方', '幂', '平方'], tpl: '#{x}^{#{2}}' },
  { zh: '下标', en: 'subscript', py: 'xia biao', alias: [], tpl: '#{x}_{#{i}}' },
  { zh: '绝对值', en: 'absolute value', py: 'jue dui zhi', alias: ['abs'], tpl: '\\left| #{x} \\right|' },
  { zh: '约等于', en: 'approximately', py: 'yue deng yu', alias: ['approx'], tpl: '#{a} \\approx #{b}' },
  { zh: '不等于', en: 'not equal', py: 'bu deng yu', alias: ['neq'], tpl: '#{a} \\neq #{b}' },
  { zh: '分段函数', en: 'piecewise function', py: 'fen duan han shu', alias: ['cases'], tpl: 'f(x) = \\begin{cases} #{a} & #{x \\ge 0} \\\\ #{b} & #{x < 0} \\end{cases}' },

  // 微积分
  { zh: '定积分', en: 'definite integral', py: 'ding ji fen', alias: ['积分'], tpl: '\\int_{#{a}}^{#{b}} #{f(x)}\\,dx' },
  { zh: '不定积分', en: 'indefinite integral', py: 'bu ding ji fen', alias: ['积分', '原函数'], tpl: '\\int #{f(x)}\\,dx' },
  { zh: '反常积分', en: 'improper integral', py: 'fan chang ji fen', alias: ['广义积分', '积分'], tpl: '\\int_{#{a}}^{\\infty} #{f(x)}\\,dx' },
  { zh: '二重积分', en: 'double integral', py: 'er chong ji fen', alias: ['积分'], tpl: '\\iint_{#{D}} #{f(x,y)}\\,dA' },
  { zh: '曲线积分', en: 'line integral', py: 'qu xian ji fen', alias: ['积分'], tpl: '\\oint_{#{C}} #{\\mathbf{F}} \\cdot d\\mathbf{r}' },
  { zh: '极限', en: 'limit', py: 'ji xian', alias: ['lim'], tpl: '\\lim_{#{x} \\to #{a}} #{f(x)}' },
  { zh: '导数', en: 'derivative', py: 'dao shu', alias: ['求导', '微分'], tpl: '\\frac{d#{y}}{d#{x}}' },
  { zh: '偏导数', en: 'partial derivative', py: 'pian dao shu', alias: ['偏导'], tpl: '\\frac{\\partial #{f}}{\\partial #{x}}' },
  { zh: '二阶导数', en: 'second derivative', py: 'er jie dao shu', alias: ['求导'], tpl: '\\frac{d^2#{y}}{d#{x}^2}' },
  { zh: '求和', en: 'summation', py: 'qiu he', alias: ['累加', 'sum', '西格玛'], tpl: '\\sum_{#{i=1}}^{#{n}} #{a_i}' },
  { zh: '连乘', en: 'product', py: 'lian cheng', alias: ['累乘', 'prod'], tpl: '\\prod_{#{i=1}}^{#{n}} #{a_i}' },
  { zh: '泰勒展开', en: 'Taylor series', py: 'tai le zhan kai', alias: ['泰勒公式'], tpl: 'f(x) = \\sum_{n=0}^{\\infty} \\frac{f^{(n)}(#{a})}{n!}(x-#{a})^n' },
  { zh: '梯度', en: 'gradient', py: 'ti du', alias: ['nabla'], tpl: '\\nabla #{f}' },

  // 线性代数
  { zh: '矩阵 2×2', en: 'matrix 2x2', py: 'ju zhen', alias: ['矩阵'], tpl: '\\begin{bmatrix} #{a} & #{b} \\\\ #{c} & #{d} \\end{bmatrix}' },
  { zh: '矩阵 3×3', en: 'matrix 3x3', py: 'ju zhen', alias: ['矩阵'], tpl: '\\begin{bmatrix} #{a} & #{b} & #{c} \\\\ #{d} & #{e} & #{f} \\\\ #{g} & #{h} & #{i} \\end{bmatrix}' },
  { zh: '行列式', en: 'determinant', py: 'hang lie shi', alias: ['det'], tpl: '\\begin{vmatrix} #{a} & #{b} \\\\ #{c} & #{d} \\end{vmatrix}' },
  { zh: '向量', en: 'vector', py: 'xiang liang', alias: ['矢量'], tpl: '\\vec{#{v}}' },
  { zh: '列向量', en: 'column vector', py: 'lie xiang liang', alias: ['向量'], tpl: '\\begin{pmatrix} #{x_1} \\\\ #{x_2} \\\\ #{x_3} \\end{pmatrix}' },
  { zh: '转置', en: 'transpose', py: 'zhuan zhi', alias: [], tpl: '#{A}^{T}' },
  { zh: '逆矩阵', en: 'inverse matrix', py: 'ni ju zhen', alias: ['矩阵的逆'], tpl: '#{A}^{-1}' },
  { zh: '内积', en: 'inner product', py: 'nei ji', alias: ['点积', '点乘', 'dot product'], tpl: '\\langle #{u}, #{v} \\rangle' },
  { zh: '范数', en: 'norm', py: 'fan shu', alias: ['模长', '长度'], tpl: '\\lVert #{x} \\rVert' },
  { zh: '特征值方程', en: 'eigenvalue equation', py: 'te zheng zhi fang cheng', alias: ['特征值', '特征向量'], tpl: '#{A}\\mathbf{v} = \\lambda \\mathbf{v}' },
  { zh: '最小二乘解', en: 'least squares', py: 'zui xiao er cheng jie', alias: ['正规方程', '最小二乘'], tpl: '\\hat{\\beta} = (X^TX)^{-1}X^Ty' },

  // 概率统计
  { zh: '期望', en: 'expectation', py: 'qi wang', alias: ['均值', '数学期望'], tpl: '\\mathbb{E}[#{X}]' },
  { zh: '方差', en: 'variance', py: 'fang cha', alias: ['var'], tpl: '\\operatorname{Var}(#{X})' },
  { zh: '协方差', en: 'covariance', py: 'xie fang cha', alias: ['cov'], tpl: '\\operatorname{Cov}(#{X}, #{Y})' },
  { zh: '样本均值', en: 'sample mean', py: 'yang ben jun zhi', alias: ['平均数', '均值'], tpl: '\\bar{x} = \\frac{1}{n}\\sum_{i=1}^{n} x_i' },
  { zh: '样本标准差', en: 'sample standard deviation', py: 'yang ben biao zhun cha', alias: ['标准差'], tpl: 's = \\sqrt{\\frac{1}{n-1}\\sum_{i=1}^{n}(x_i - \\bar{x})^2}' },
  { zh: '条件概率', en: 'conditional probability', py: 'tiao jian gai lv', alias: ['概率'], tpl: 'P(#{A} \\mid #{B}) = \\frac{P(#{A} \\cap #{B})}{P(#{B})}' },
  { zh: '贝叶斯公式', en: "Bayes' theorem", py: 'bei ye si gong shi', alias: ['贝叶斯', '概率'], tpl: 'P(A \\mid B) = \\frac{P(B \\mid A)\\,P(A)}{P(B)}' },
  { zh: '正态分布', en: 'normal distribution', py: 'zheng tai fen bu', alias: ['高斯分布'], tpl: '#{X} \\sim N(#{\\mu}, #{\\sigma^2})' },
  { zh: '正态分布密度', en: 'normal pdf', py: 'zheng tai fen bu mi du', alias: ['高斯', '概率密度'], tpl: 'f(x) = \\frac{1}{\\sigma\\sqrt{2\\pi}} e^{-\\frac{(x-\\mu)^2}{2\\sigma^2}}' },
  { zh: '二项分布', en: 'binomial distribution', py: 'er xiang fen bu', alias: [], tpl: 'P(X=k) = \\binom{#{n}}{k} #{p}^k (1-#{p})^{#{n}-k}' },
  { zh: '组合数', en: 'binomial coefficient', py: 'zu he shu', alias: ['组合', 'choose'], tpl: '\\binom{#{n}}{#{k}}' },
  { zh: '相关系数', en: 'correlation coefficient', py: 'xiang guan xi shu', alias: ['相关'], tpl: 'r = \\frac{\\operatorname{Cov}(#{X},#{Y})}{\\sigma_{#{X}}\\sigma_{#{Y}}}' },
  { zh: '线性回归', en: 'linear regression', py: 'xian xing hui gui', alias: ['回归'], tpl: '#{y} = \\beta_0 + \\beta_1 #{x} + \\varepsilon' },
]

/** 把模板拆成插入用的文字和“空”的位置 */
export function expandTemplate(tpl) {
  let text = ''
  const placeholders = []
  let last = 0
  for (const m of tpl.matchAll(/#\{([^}]*)\}/g)) {
    text += tpl.slice(last, m.index)
    placeholders.push({ start: text.length, end: text.length + m[1].length })
    text += m[1]
    last = m.index + m[0].length
  }
  text += tpl.slice(last)
  return { text, placeholders }
}

/** 预览用：第一个空涂成黄色（和设计稿一样） */
export function previewTeX(tpl) {
  let first = true
  return tpl.replace(/#\{([^}]*)\}/g, (_, inner) => {
    if (!first) return inner
    first = false
    return `\\colorbox{#ffe58f}{$${inner}$}`
  })
}

const initials = (py) => py.split(' ').map((w) => w[0]).join('')

/** 搜索：中文、英文、拼音（全拼或首字母）、别名都能搜 */
export function searchFormulas(query) {
  const q = query.trim().toLowerCase().replace(/\s+/g, '')
  if (!q) return formulas
  const scored = []
  for (const f of formulas) {
    const zh = f.zh.toLowerCase().replace(/\s+/g, '')
    const en = f.en.toLowerCase().replace(/\s+/g, '')
    const py = f.py.replace(/\s+/g, '')
    let score = 0
    if (zh === q) score = 100
    else if (zh.startsWith(q)) score = 80
    else if (zh.includes(q)) score = 60
    else if (py.startsWith(q) || initials(f.py).startsWith(q)) score = 50
    else if (f.alias.some((a) => a.toLowerCase() === q)) score = 45
    else if (en.startsWith(q)) score = 40
    else if (f.alias.some((a) => a.toLowerCase().includes(q))) score = 30
    else if (en.includes(q) || py.includes(q)) score = 20
    if (score) scored.push({ f, score })
  }
  return scored.sort((a, b) => b.score - a.score).map((s) => s.f)
}
