// 公式库：每条有中文名、英文名、拼音、别名和带“空”的模板。
// 模板里 #{…} 是一个“空”：插入后先选中第一个空，Tab 跳到下一个。
// 分类：基础写法、微积分、线性代数、概率统计、希腊字母、集合、逻辑和证明。

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

  // 希腊字母（搜中文名、英文名、拼音都行；大写的搜“大写 西塔”或 Theta）
  { zh: 'α 阿尔法', en: 'alpha', py: 'a er fa', alias: ['α', '希腊字母'], tpl: '\\alpha' },
  { zh: 'β 贝塔', en: 'beta', py: 'bei ta', alias: ['β', '希腊字母'], tpl: '\\beta' },
  { zh: 'γ 伽马', en: 'gamma', py: 'ga ma', alias: ['γ', '希腊字母'], tpl: '\\gamma' },
  { zh: 'Γ 大写伽马', en: 'Gamma (capital gamma)', py: 'da xie ga ma', alias: ['Γ', '希腊字母'], tpl: '\\Gamma' },
  { zh: 'δ 德尔塔', en: 'delta', py: 'de er ta', alias: ['δ', '希腊字母'], tpl: '\\delta' },
  { zh: 'Δ 大写德尔塔', en: 'Delta (capital delta)', py: 'da xie de er ta', alias: ['Δ', '希腊字母'], tpl: '\\Delta' },
  { zh: 'ε 艾普西隆', en: 'epsilon', py: 'ai pu xi long', alias: ['ε', '希腊字母'], tpl: '\\epsilon' },
  { zh: 'ζ 泽塔', en: 'zeta', py: 'ze ta', alias: ['ζ', '希腊字母'], tpl: '\\zeta' },
  { zh: 'η 伊塔', en: 'eta', py: 'yi ta', alias: ['η', '希腊字母'], tpl: '\\eta' },
  { zh: 'θ 西塔', en: 'theta', py: 'xi ta', alias: ['θ', '希腊字母'], tpl: '\\theta' },
  { zh: 'Θ 大写西塔', en: 'Theta (capital theta)', py: 'da xie xi ta', alias: ['Θ', '希腊字母'], tpl: '\\Theta' },
  { zh: 'ι 约塔', en: 'iota', py: 'yue ta', alias: ['ι', '希腊字母'], tpl: '\\iota' },
  { zh: 'κ 卡帕', en: 'kappa', py: 'ka pa', alias: ['κ', '希腊字母'], tpl: '\\kappa' },
  { zh: 'λ 兰姆达', en: 'lambda', py: 'lan mu da', alias: ['λ', '希腊字母'], tpl: '\\lambda' },
  { zh: 'Λ 大写兰姆达', en: 'Lambda (capital lambda)', py: 'da xie lan mu da', alias: ['Λ', '希腊字母'], tpl: '\\Lambda' },
  { zh: 'μ 缪', en: 'mu', py: 'miu', alias: ['μ', '希腊字母'], tpl: '\\mu' },
  { zh: 'ν 纽', en: 'nu', py: 'niu', alias: ['ν', '希腊字母'], tpl: '\\nu' },
  { zh: 'ξ 克西', en: 'xi', py: 'ke xi', alias: ['ξ', '希腊字母'], tpl: '\\xi' },
  { zh: 'Ξ 大写克西', en: 'Xi (capital xi)', py: 'da xie ke xi', alias: ['Ξ', '希腊字母'], tpl: '\\Xi' },
  { zh: 'π 派', en: 'pi', py: 'pai', alias: ['π', '希腊字母'], tpl: '\\pi' },
  { zh: 'Π 大写派', en: 'Pi (capital pi)', py: 'da xie pai', alias: ['Π', '希腊字母'], tpl: '\\Pi' },
  { zh: 'ρ 肉', en: 'rho', py: 'rou', alias: ['ρ', '希腊字母'], tpl: '\\rho' },
  { zh: 'σ 西格玛', en: 'sigma', py: 'xi ge ma', alias: ['σ', '希腊字母'], tpl: '\\sigma' },
  { zh: 'Σ 大写西格玛', en: 'Sigma (capital sigma)', py: 'da xie xi ge ma', alias: ['Σ', '希腊字母'], tpl: '\\Sigma' },
  { zh: 'τ 陶', en: 'tau', py: 'tao', alias: ['τ', '希腊字母'], tpl: '\\tau' },
  { zh: 'υ 宇普西隆', en: 'upsilon', py: 'yu pu xi long', alias: ['υ', '希腊字母'], tpl: '\\upsilon' },
  { zh: 'Υ 大写宇普西隆', en: 'Upsilon (capital upsilon)', py: 'da xie yu pu xi long', alias: ['Υ', '希腊字母'], tpl: '\\Upsilon' },
  { zh: 'φ 斐', en: 'phi', py: 'fei', alias: ['φ', '希腊字母'], tpl: '\\phi' },
  { zh: 'Φ 大写斐', en: 'Phi (capital phi)', py: 'da xie fei', alias: ['Φ', '希腊字母'], tpl: '\\Phi' },
  { zh: 'χ 希', en: 'chi', py: 'xi', alias: ['χ', '希腊字母'], tpl: '\\chi' },
  { zh: 'ψ 普西', en: 'psi', py: 'pu xi', alias: ['ψ', '希腊字母'], tpl: '\\psi' },
  { zh: 'Ψ 大写普西', en: 'Psi (capital psi)', py: 'da xie pu xi', alias: ['Ψ', '希腊字母'], tpl: '\\Psi' },
  { zh: 'ω 欧米伽', en: 'omega', py: 'ou mi jia', alias: ['ω', '希腊字母'], tpl: '\\omega' },
  { zh: 'Ω 大写欧米伽', en: 'Omega (capital omega)', py: 'da xie ou mi jia', alias: ['Ω', '希腊字母'], tpl: '\\Omega' },
  { zh: 'ε 变体', en: 'varepsilon', py: 'ai pu xi long', alias: ['ε'], tpl: '\\varepsilon' },
  { zh: 'θ 变体', en: 'vartheta', py: 'xi ta', alias: ['ϑ'], tpl: '\\vartheta' },
  { zh: 'φ 变体', en: 'varphi', py: 'fei', alias: ['ϕ'], tpl: '\\varphi' },

  // 集合
  { zh: '属于', en: 'element of', py: 'shu yu', alias: ['∈', 'in'], tpl: '#{x} \\in #{A}' },
  { zh: '不属于', en: 'not element of', py: 'bu shu yu', alias: ['∉', 'notin'], tpl: '#{x} \\notin #{A}' },
  { zh: '子集', en: 'subset', py: 'zi ji', alias: ['包含于', '⊆', 'subseteq'], tpl: '#{A} \\subseteq #{B}' },
  { zh: '真子集', en: 'proper subset', py: 'zhen zi ji', alias: ['⊊', 'subsetneq'], tpl: '#{A} \\subsetneq #{B}' },
  { zh: '超集', en: 'superset', py: 'chao ji', alias: ['包含', '⊇', 'supseteq'], tpl: '#{A} \\supseteq #{B}' },
  { zh: '并集', en: 'union', py: 'bing ji', alias: ['∪', 'cup', '并'], tpl: '#{A} \\cup #{B}' },
  { zh: '交集', en: 'intersection', py: 'jiao ji', alias: ['∩', 'cap', '交'], tpl: '#{A} \\cap #{B}' },
  { zh: '差集', en: 'set difference', py: 'cha ji', alias: ['setminus', '减'], tpl: '#{A} \\setminus #{B}' },
  { zh: '补集', en: 'complement', py: 'bu ji', alias: ['余集'], tpl: '#{A}^{c}' },
  { zh: '空集', en: 'empty set', py: 'kong ji', alias: ['∅', 'emptyset'], tpl: '\\varnothing' },
  { zh: '集合（列举）', en: 'set (roster)', py: 'ji he', alias: ['集合', '花括号'], tpl: '\\{ #{1, 2, 3} \\}' },
  { zh: '集合（描述法）', en: 'set-builder notation', py: 'ji he miao shu fa', alias: ['集合'], tpl: '\\{ #{x} \\in #{\\mathbb{R}} \\mid #{x > 0} \\}' },
  { zh: '自然数集', en: 'natural numbers', py: 'zi ran shu ji', alias: ['ℕ', '数集'], tpl: '\\mathbb{N}' },
  { zh: '整数集', en: 'integers', py: 'zheng shu ji', alias: ['ℤ', '数集'], tpl: '\\mathbb{Z}' },
  { zh: '有理数集', en: 'rational numbers', py: 'you li shu ji', alias: ['ℚ', '数集'], tpl: '\\mathbb{Q}' },
  { zh: '实数集', en: 'real numbers', py: 'shi shu ji', alias: ['ℝ', '数集'], tpl: '\\mathbb{R}' },
  { zh: '复数集', en: 'complex numbers', py: 'fu shu ji', alias: ['ℂ', '数集'], tpl: '\\mathbb{C}' },
  { zh: 'n 维实数空间', en: 'real n-space', py: 'shi shu kong jian', alias: ['ℝⁿ', '数集'], tpl: '\\mathbb{R}^{#{n}}' },
  { zh: '笛卡尔积', en: 'Cartesian product', py: 'di ka er ji', alias: ['直积'], tpl: '#{A} \\times #{B}' },
  { zh: '幂集', en: 'power set', py: 'mi ji', alias: [], tpl: '\\mathcal{P}(#{A})' },
  { zh: '集合的元素个数', en: 'cardinality', py: 'yuan su ge shu', alias: ['基数', '势'], tpl: '\\lvert #{A} \\rvert' },
  { zh: '多个集合的并', en: 'big union', py: 'bing ji', alias: ['并集', 'bigcup'], tpl: '\\bigcup_{#{i=1}}^{#{n}} #{A_i}' },
  { zh: '多个集合的交', en: 'big intersection', py: 'jiao ji', alias: ['交集', 'bigcap'], tpl: '\\bigcap_{#{i=1}}^{#{n}} #{A_i}' },
  { zh: '区间', en: 'interval', py: 'qu jian', alias: ['闭区间', '开区间'], tpl: '[#{a}, #{b}]' },

  // 逻辑和证明（mathematical statement）
  { zh: '任意', en: 'for all', py: 'ren yi', alias: ['对所有', '∀', 'forall', '全称'], tpl: '\\forall #{x} \\in #{A}' },
  { zh: '存在', en: 'there exists', py: 'cun zai', alias: ['∃', 'exists', '存在量词'], tpl: '\\exists #{x} \\in #{A}' },
  { zh: '存在唯一', en: 'there exists a unique', py: 'cun zai wei yi', alias: ['∃!', '唯一'], tpl: '\\exists! #{x}' },
  { zh: '不存在', en: 'there does not exist', py: 'bu cun zai', alias: ['∄', 'nexists'], tpl: '\\nexists #{x}' },
  { zh: '推出', en: 'implies', py: 'tui chu', alias: ['蕴含', '如果那么', '⇒', 'implies', 'then'], tpl: '#{P} \\implies #{Q}' },
  { zh: '当且仅当', en: 'if and only if', py: 'dang qie jin dang', alias: ['等价', '充要', '⇔', 'iff'], tpl: '#{P} \\iff #{Q}' },
  { zh: '非', en: 'not', py: 'fei', alias: ['否定', '¬', 'neg'], tpl: '\\neg #{P}' },
  { zh: '且', en: 'and', py: 'qie', alias: ['合取', '∧', 'land'], tpl: '#{P} \\land #{Q}' },
  { zh: '或', en: 'or', py: 'huo', alias: ['析取', '∨', 'lor'], tpl: '#{P} \\lor #{Q}' },
  { zh: '因为', en: 'because', py: 'yin wei', alias: ['∵'], tpl: '\\because' },
  { zh: '所以', en: 'therefore', py: 'suo yi', alias: ['因此', '∴'], tpl: '\\therefore' },
  { zh: '定义为', en: 'defined as', py: 'ding yi wei', alias: [':=', '记作', 'coloneqq'], tpl: '#{f(x)} \\coloneqq #{x^2}' },
  { zh: '恒等于', en: 'identically equal', py: 'heng deng yu', alias: ['≡', 'equiv'], tpl: '#{a} \\equiv #{b}' },
  { zh: '同余', en: 'congruent modulo', py: 'tong yu', alias: ['mod', '取模'], tpl: '#{a} \\equiv #{b} \\pmod{#{n}}' },
  { zh: '映射', en: 'function mapping', py: 'ying she', alias: ['函数', '→'], tpl: '#{f} : #{A} \\to #{B}' },
  { zh: '元素映射到', en: 'maps to', py: 'ying she dao', alias: ['↦', 'mapsto'], tpl: '#{x} \\mapsto #{f(x)}' },
  { zh: 'ε-δ 定义', en: 'epsilon-delta definition', py: 'ai pu xi long de er ta', alias: ['极限定义', '连续'], tpl: '\\forall \\varepsilon > 0,\\ \\exists \\delta > 0 : |x - #{a}| < \\delta \\implies |f(x) - #{L}| < \\varepsilon' },
  { zh: '证毕', en: 'QED', py: 'zheng bi', alias: ['∎', 'qed', 'end of proof'], tpl: '\\blacksquare' },
  { zh: '小于等于', en: 'less than or equal', py: 'xiao yu deng yu', alias: ['≤', 'le', 'leq'], tpl: '#{a} \\le #{b}' },
  { zh: '大于等于', en: 'greater than or equal', py: 'da yu deng yu', alias: ['≥', 'ge', 'geq'], tpl: '#{a} \\ge #{b}' },
  { zh: '无穷', en: 'infinity', py: 'wu qiong', alias: ['∞', 'infty', '无穷大'], tpl: '\\infty' },
  { zh: '正比于', en: 'proportional to', py: 'zheng bi yu', alias: ['∝', 'propto'], tpl: '#{y} \\propto #{x}' },
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
    else if (en === q) score = 90 // 英文名正好对上（theta → θ，不是 Θ 或变体）
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
