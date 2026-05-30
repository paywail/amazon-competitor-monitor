---
name: amazon-competitor-monitor
description: 亚马逊竞品监控与分析，自动采集竞品数据并生成报告。适用场景：(1) 用户要求监控亚马逊竞品；(2) 用户需要分析竞品价格/促销/卖点/图片变化；(3) 用户需要生成竞品周报；(4) 用户提及"课题 4"、"竞品监控"、"亚马逊运营"等关键词。支持日本站 (.co.jp)、美国站 (.com) 等站点。
metadata:
  version: "3.0.0"
  features:
    - 自动定时采集（每日）
    - 历史数据保存（按日期命名）
    - AI 智能分析竞品变动（调用 AI 模型）
    - 结合我方产品生成针对性建议
    - 对比分析（自动对比前一日数据）
    - 图片变化检测（URL 对比 + 截图 AI 分析）
    - 标准化报告格式
    - 查询后输出完整 md 内容
    - 5 列竞品变动汇总表（字段/今日/昨日/变动/说明）
    - 标题字段简化展示（仅记录变动状态）
    - 精简报告结构
    - 英文内容附中文翻译（标题、卖点）
  changes:
    - v3.0.0: 新增 AI 智能分析模块，采集后调用 AI 模型分析变动、生成行动建议，结合我方产品 ASIN 给出针对性策略
    - v2.8.5: 竞品详细数据中的英文标题和卖点添加中文翻译，便于快速阅读
    - v2.8.4: 品牌字段优化，从"Visit the XXX Store"提取纯品牌名（如 YeTom）
    - v2.8.3: 移除"【与前一日对比】"和"【图片变化详情】"章节，进一步精简报告
    - v2.8.2: 移除"六、复盘对照指标"章节，精简报告结构
    - v2.8.1: 标题字段简化为"已记录"，仅用于后台对比变动，不展示完整标题
    - v2.8.0: 优化竞品变动汇总表为 5 列格式（采集字段、今日数据、昨日数据、变动标注、变动说明），每个 ASIN 独立展示 15 个采集字段
    - v2.7.0: 新增促销活动数据采集（位于优惠券前）
    - v2.6.0: 新增品牌数据采集（位于 ASIN 后），BSR 排名移至五点卖点前
    - v2.5.0: 新增积分数据采集（位于评分前），库存状态中文化
    - v2.4.0: 新增库存状态数据采集（位于评论数后）
    - v2.3.0: 移除 Prime 数据采集（日本站 Prime 覆盖率低，数据价值有限）
---

# 亚马逊竞品监控 Skill

## 核心流程

```
1. 读取配置 → 2. 检查历史数据 → 3. 采集数据（含图片） → 4. 对比分析 → 5. 生成报告 → 6. 保存文件 → 7. 输出完整 md 内容给用户
```

---

## 一、配置文件

监控对象配置在 `config.json`：

```json
{
  "schedule": {
    "enabled": true,
    "cron": "0 9 * * *",
    "tz": "Asia/Shanghai"
  },
  "targets": [
    {
      "name": "指定 ASIN",
      "type": "asin",
      "asins": ["B0B5GDT7LD", "B0CZKTN5QK", "B0C36ZHS6Q"],
      "limit": 3
    }
  ],
  "output": {
    "dir": "workspace/amazon-competitor",
    "filenamePattern": "amazon-competitor-report-{YYYY-MM-DD}.md"
  },
  "delivery": {
    "postalCode": "100-0001",
    "country": "JP"
  }
}
```

---

## 二、数据采集（使用 web-access CDP）

### 前置条件

```bash
node "$HOME/.agents/skills/web-access/scripts/check-deps.mjs"
```

### 配送地址设置

**重要**：必须设置日本配送地址以获取正确的日本市场价格！

```javascript
// 设置配送邮编为日本 100-0001（东京都千代田区）
// 在亚马逊首页点击配送地址链接
// 输入邮编 100-0001
// 点击 Apply/确认
```

### 采集数据字段（含图片）

| 字段 | DOM 选择器 | 说明 |
|------|-----------|------|
| ASIN | `data-asin` 或 URL 匹配 | 商品唯一标识 |
| **品牌** | `#bylineInfo` | 品牌信息，需提取纯品牌名（从"Visit the XXX Store"中提取"XXX"） |
| 标题 | `#productTitle` | 商品名称（仅用于对比变动，报告中显示"已记录"） |
| 售价 | `.a-price .a-offscreen` | 当前售价 |
| 划线价 | `.a-price.a-text-price .a-offscreen` | 原价（如有） |
| **促销活动** | `[class*=deal], [class*=promotion], #dealBadge` | 促销活动标识（如"Limited time deal"） |
| 优惠券 | `#promoPriceBlockMessage_feature_div` | Coupon/促销信息 |
| **积分** | `.a-section .a-color-price` (含"pt"的项) | 亚马逊积分（如"66pt (1%)"） |
| 评分 | `[data-hook=average-star-rating]` | 星级评分（平均值） |
| 评论数 | `#acrCustomerReviewLink span` | 评论总数 |
| **库存状态** | `#availability span` | 库存状态（自动转为中文） |
| **BSR 排名** | `#SalesRank` 或 `.prodDetSectionEntry` | 类目排名（如有） |
| 五点卖点 | `#featurebullets_feature_div li span.a-list-item` | 核心卖点（取前 5 条） |
| **主图 URL** | `#landingImage, #main-image` | 商品主图链接 |
| **图片数量** | `#altImages li` | 商品图片总数 |
| **图片列表** | `#altImages img, .a-button-toggle img` | 所有图片 URL |

### 品牌名称提取代码

```javascript
// 从#bylineInfo 提取纯品牌名（去除"Visit the "和" Store"）
const bylineRaw = document.querySelector('#bylineInfo')?.innerText?.trim() || '';
const brand = bylineRaw
  .replace(/^Visit the\s+/i, '')  // 移除开头的"Visit the "
  .replace(/\s+Store$/, '')        // 移除结尾的" Store"
  .trim();
```

### 图片采集代码

```javascript
// 采集图片数据
const mainImage = document.querySelector('#landingImage')?.src || 
                 document.querySelector('#main-image')?.src || 
                 document.querySelector('img[data-image]')?.src || '';
const imageCount = document.querySelectorAll('#altImages li').length || 1;
const allImages = Array.from(document.querySelectorAll('#altImages img, .a-button-toggle img'))
  .map(img => img.src)
  .filter(src => src && !src.includes('transparent'));

const imageData = {
  mainImage: mainImage,
  imageCount: imageCount,
  allImages: allImages.slice(0, 7)  // 取前 7 张
};
```

---

## 三、图片变化检测（两种方案）

### 方案 1：URL 对比（简单快速）

**原理**：记录主图 URL，对比前后变化

```javascript
// 对比主图 URL
if (prevMainImage !== currentMainImage) {
  // 主图已更换
  changeLog.mainImageChange = {
    old: prevMainImage,
    new: currentMainImage,
    status: "已更换"
  };
}

// 对比图片数量
if (prevImageCount !== currentImageCount) {
  changeLog.imageCountChange = {
    old: prevImageCount,
    new: currentImageCount,
    diff: currentImageCount - prevImageCount
  };
}
```

**输出格式**：

```markdown
| ASIN | 主图变化 | 图片数量变化 | 备注 |
|------|----------|--------------|------|
| B01G4JMQFW | 无变化 | 无变化 | 稳定 |
| B0CQ2J43ZD | 已更换 | ↑ 2 张 | 🔴 Listing 优化 |
```

---

### 方案 2：截图 + AI 分析（完整深度）

**原理**：每次采集截图保存主图，AI 对比前后差异

```bash
# 截图保存主图
curl -s "http://localhost:3456/screenshot?target=ID&file=/tmp/product-{ASIN}-main.png"
```

**AI 分析指令**：

```
对比两张商品主图的差异：
1. 图片风格变化：白底图 → 场景图 / 场景图 → 白底图
2. 产品角度变化：正面 → 斜侧 / 斜侧 → 正面
3. 背景变化：纯白背景 → 生活场景 / 深色背景 → 浅色背景
4. 产品细节变化：是否展示更多细节
5. 视觉吸引力变化：哪张更有吸引力

输出格式：
- 主图风格：{白底/场景/混合}
- 变化描述：{具体变化}
- 影响评估：{可能影响转化}
```

**输出格式**：

```markdown
| ASIN | 主图风格变化 | 视觉差异描述 | 影响评估 |
|------|--------------|--------------|----------|
| B01G4JMQFW | 白底 → 场景 | 增加办公场景背景 | 🔵 可能提升转化 |
| B0CQ2J43ZD | 无变化 | 无变化 | 无影响 |
```

---

## 四、历史数据对比（完整维度）

### 对比维度表

| 对比项 | 变动标注 | 说明 |
|--------|----------|------|
| **价格变动** | ↑ ¥500 / ↓ ¥300 / 无变化 | 对比售价变化 |
| **划线价变动** | 新增/取消/变化 | 划线价策略变化 |
| **评论增长** | +50 / +100 / 无变化 | 评论增长速度 |
| **评分变化** | ↑ 0.1 / ↓ 0.1 / 无变化 | 评分变化 |
| **促销变化** | 新增 Coupon/取消 Coupon/折扣变化 | 促销策略变化 |
| **库存状态** | 有货/缺货/库存紧张 | 库存可用性变化 |
| **卖点变化** | 新增卖点/修改卖点 | Listing 优化变化 |
| **主图更换** | 已更换 / 无变化 | 主图 URL 变化 |
| **图片数量** | ↑ 2 张 / ↓ 1 张 / 无变化 | 图片总数变化 |
| **图片风格** | 白底→场景 / 场景→白底 / 无变化 | AI 视觉分析风格变化 |

---

## 四、AI 智能分析（核心模块）

### AI 分析指令模板

采集数据后，调用 AI 模型对竞品变动进行智能分析，生成针对性行动建议。

**标准版分析指令**：

```
请你担任亚马逊竞品运营分析师，根据以下竞品数据完成分析：

【我方产品】
ASIN: B0BPP7WPLF

【竞品数据】
{竞品 1 ASIN}: {品牌} - 售价¥{价格}, 评分{评分}, 评论{评论数}, 促销{促销}
{竞品 2 ASIN}: {品牌} - 售价¥{价格}, 评分{评分}, 评论{评论数}, 促销{促销}
{竞品 3 ASIN}: {品牌} - 售价¥{价格}, 评分{评分}, 评论{评论数}, 促销{促销}

【与前一日对比变动】
{竞品 1}: 价格变动{变动}, 评论增长{增长}, 促销变化{促销变化}
{竞品 2}: ...
{竞品 3}: ...

请按以下要求输出分析结果：

1. **影响等级判定**：对每一处变动判定影响等级
   - 🔴 高度威胁：直接影响转化和销量（价格战、大幅 Coupon、评论碾压）
   - 🟠 中度冲击：可能分流部分用户（划线价、差异化卖点）
   - 🟡 轻微影响：需关注但不紧急（企业促销、新品入场）
   - ⚪ 无实质影响：对个人消费者影响小

2. **行动建议**：结合我方产品现状，给出具体可落地的运营应对动作
   - 🔴 立即执行（1-2 天内）：价格战跟进、Coupon 监控、Listing 紧急优化
   - 🟡 本周跟进（本周内）：卖点强化、划线价策略、广告调整
   - 🟢 长期观察（持续）：评论积累、产品线扩展、市场趋势

3. **竞争局势总结**：汇总本周整体竞争局势，标注风险点

4. **下周监控方向**：列出下周重点监控方向

输出格式为 markdown 表格，条理清晰，结论明确。
```

### 分析维度说明

| 维度 | 分析点 | 判断标准 |
|------|--------|----------|
| 价格 | 价格区间 | 是否进入新价格区间（如 7000 日元以下） |
| 价格 | 划线价 | 是否使用划线价制造折扣感 |
| 价格 | 优惠券 | Coupon 百分比、是否有促销叠加 |
| 卖点 | 核心卖点 | 尺寸、承重、收纳、组装、显示器臂等 |
| 卖点 | 新卖点 | 是否新增卖点描述 |
| 评价 | 评分变化 | 评分是否下降（<4.2 需警惕） |
| 评价 | 评论增长 | 评论增长速度（老品 vs 新品） |

---

## 五、报告输出格式（标准格式）

使用 `references/report-template.md` 模板输出：

```markdown
# 亚马逊竞品监控报告

**统计周期**：{YYYY 年 MM 月 DD 日}
**监控竞品数量**：{N}款
**监控对象**：BS 榜单前{N} + 搜索页前{N} + 指定 ASIN {N}个（去重后{N}款）
**站点**：{站点}
**类目**：{类目}

---

### 一、竞品变动汇总表

**竞品 ASIN：{ASIN} - {品牌}**

| 采集字段 | 今日数据 | 昨日数据 | 变动标注 | 变动说明 |
|----------|----------|----------|----------|----------|
| **ASIN** | {ASIN} | {ASIN} | - | - |
| **品牌** | {品牌} | {品牌} | - | - |
| **标题** | {已记录} | {已记录} | {无变化/已修改} | {标题是否变更} |
| **售价** | ¥{售价} | ¥{昨日售价} | {无变化/↑¥XX/↓¥XX} | {说明} |
| **划线价** | ¥{划线价} | ¥{昨日划线价} | {无变化/新增/取消} | {说明} |
| **促销活动** | {促销} | {昨日促销} | {无变化/新增/取消} | {说明} |
| **优惠券** | {优惠券} | {昨日优惠券} | {无变化/新增/取消/变化} | {说明} |
| **积分** | {积分} | {昨日积分} | {无变化/变化} | {说明} |
| **评分** | ⭐{评分} | ⭐{昨日评分} | {无变化/↑0.X/↓0.X} | {说明} |
| **评论数** | {评论数} | {昨日评论数} | {+XX/无变化} | {说明} |
| **库存状态** | {库存} | {昨日库存} | {无变化/变化} | {说明} |
| **BSR 排名** | {BSR} | {昨日 BSR} | {无变化/变化} | {说明} |
| **五点卖点** | {N}条 | {昨日 N}条 | {无变化/新增/修改} | {说明} |
| **主图** | [查看]({URL}) | [查看]({昨日 URL}) | {无变化/已更换} | {说明} |
| **图片数量** | {N}张 | {昨日 N}张 | {无变化/↑X 张/↓X 张} | {说明} |

---

### 二、竞品变动影响分级评估

#### 🔴 高度威胁变动
#### 🟠 中度冲击变动
#### 🟡 轻微影响变动
#### ⚪ 无实质影响变动

---

### 三、分优先级行动建议

#### 🔴 立即执行
#### 🟡 本周跟进
#### 🟢 长期观察

---

### 四、本周竞争整体总结

---

### 五、下周重点盯防方向

---

## 附：竞品详细数据

### {ASIN} - {品牌}
- 品牌：{品牌名称}
- 标题：{完整标题（英文原文）} / {中文翻译}
- 售价：¥{售价}（划线价：¥{划线价}）
- 积分：{积分}
- 评分：⭐{评分} / 评论：{评论数}
- 库存状态：{库存}
- BSR 排名：{BSR}
- 主图：{主图 URL}
- 图片数量：{N}张
- 五点卖点：{完整五点（英文原文 + 中文翻译）}

**注意**：日本站商品标题和卖点多为英文，报告中应保留英文原文并附上中文翻译，便于快速阅读。
```

---

## 六、文件保存规则

### 文件命名

```
amazon-competitor-report-{YYYY-MM-DD}.md
```

### 保存路径

```
workspace/amazon-competitor/amazon-competitor-report-{YYYY-MM-DD}.md
```

---

## 七、执行流程

### 步骤 1：读取配置

```bash
read(path="$HOME/.agents/skills/amazon-competitor-monitor/config.json")
```

### 步骤 2：检查历史数据

```bash
# 检查前一日文件
ls workspace/amazon-competitor/amazon-competitor-report-{昨日}.md

# 如果存在，读取历史数据
read(path="amazon-competitor/amazon-competitor-report-{昨日}.md")
```

### 步骤 3：启动 CDP

```bash
node "$HOME/.agents/skills/web-access/scripts/check-deps.mjs"
```

### 步骤 4：设置配送地址

```javascript
// 打开亚马逊首页
// 点击配送地址链接
// 输入日本邮编 100-0001
// 点击 Apply/确认
```

### 步骤 5：采集数据（含图片）

```javascript
// 采集商品详情 + 图片数据
const data = {
  // 基本信息
  asin, title, price, listPrice, rating, reviewCount, stock, bullets,
  // 图片数据
  mainImage: mainImageUrl,
  imageCount: imageCount,
  allImages: imageUrls
};
```

### 步骤 6：对比分析

```
如果有前一日数据：
- 对比价格变动
- 对比评论增长
- 对比促销变化
- 对比主图 URL 变化
- 对比图片数量变化
- 截图对比（如有变化）→ AI 分析风格差异
```

### 步骤 7：AI 智能分析（核心步骤）

**调用 AI 模型分析竞品变动，生成针对性行动建议**

```javascript
// 构造分析数据
const analysisData = {
  myProduct: { asin: "B0BPP7WPLF" },
  competitors: [
    { asin: "B0B5GDT7LD", brand: "YeTom", price: "¥6,619", rating: "4.2", reviews: "1690", promotion: "限时特惠" },
    { asin: "B0CZKTN5QK", brand: "GTRACING", price: "¥12,000", rating: "4.2", reviews: "842", promotion: "-" },
    { asin: "B0C36ZHS6Q", brand: "Maihail", price: "¥6,921", rating: "4.1", reviews: "275", promotion: "5% OFF" }
  ],
  changes: [
    { asin: "B0B5GDT7LD", priceChange: "划线价↓¥1,422", reviewChange: "0", promotionChange: "新增限时特惠" },
    { asin: "B0CZKTN5QK", priceChange: "无", reviewChange: "0", promotionChange: "无" },
    { asin: "B0C36ZHS6Q", priceChange: "无", reviewChange: "+1", promotionChange: "新增 5% 优惠券" }
  ]
};

// 调用 AI 模型（使用 sessions_spawn 或直接调用）
const prompt = `请你担任亚马逊竞品运营分析师...（完整指令见"四、AI 智能分析"章节）`;
const analysis = await callAI(prompt);
```

**AI 分析输出示例**：

```markdown
#### 🔴 高度威胁变动
| 变动 | 竞品 | 影响分析 | 理由 |
|------|------|----------|------|
| 划线价下调 + 限时特惠 | YeTom | 价格竞争力增强 | 划线价从 ¥8,633 降至 ¥7,211，配合"限时特惠"标签可能提升转化 |

#### 🟠 中度冲击变动
| 变动 | 竞品 | 影响分析 | 理由 |
|------|------|----------|------|
| 新增 5% 优惠券 | Maihail | 实际到手价降低 | 新增 5% 优惠券（约 ¥346），实际到手价约 ¥6,575 |

### 三、分优先级行动建议

#### 🔴 立即执行（1-2 天内完成）
| 序号 | 行动 | 具体操作 | 负责人 | 截止 |
|------|------|----------|--------|------|
| 1 | 检查 YeTom 限时特惠活动详情 | 确认活动结束时间、折扣力度是否可持续 | 运营 | 当日 |

#### 🟡 本周跟进优化
| 序号 | 行动 | 具体操作 | 负责人 | 截止 |
|------|------|----------|--------|------|
| 4 | 评估价格策略调整 | 根据竞品促销情况，评估是否需要跟进 | 运营 | 周五 |
```

### 步骤 8：生成报告

按照标准格式生成报告，**整合 AI 分析结果**到对应章节：
- 二、竞品变动影响分级评估（使用 AI 判定的影响等级）
- 三、分优先级行动建议（使用 AI 生成的行动建议）
- 四、本周竞争整体总结（使用 AI 总结的竞争局势）
- 五、下周重点盯防方向（使用 AI 建议的监控方向）

### 步骤 9：保存文件

```bash
write(path="amazon-competitor/amazon-competitor-report-{今日}.md", content=报告)
```

### 步骤 10：输出完整内容给用户（重要！）

**必须执行**：在查询完成后，将完整报告内容以 markdown 格式直接发送给用户！

```markdown
# 亚马逊竞品监控报告
...（完整报告内容，包含 AI 分析结果）
```

---

## 八、注意事项

1. **图片采集**：每次必须采集主图 URL 和图片数量
2. **图片对比**：URL 变化必须标注，截图对比可选
3. **格式一致**：报告必须按照标准格式输出
4. **动态路径**：使用相对路径 `workspace/amazon-competitor`
5. **清理 Tab**：采集完成后关闭商品详情页 tab
6. **反爬规避**：使用用户 Chrome 登录态
7. **配送地址设置**：必须设置日本配送地址（邮编 100-0001）以获取正确的日本市场价格
8. **输出规则**：**查询完成后，必须将完整报告内容以 markdown 格式直接发送给用户**，不要只发送文件

---

## 九、输出规则（重要）

### 必须执行的输出流程

1. **生成报告文件** - 保存到 `workspace/amazon-competitor/amazon-competitor-report-{YYYY-MM-DD}.md`
2. **发送文件给用户** - 通过 message 工具发送文件
3. **直接输出完整内容** - **在回复中以 markdown 代码块形式输出完整报告内容**

### 示例

````markdown
# 亚马逊竞品监控报告
**统计周期**：2026 年 05 月 28 日
**监控竞品数量**：3 款
...（完整报告内容）
````

**不要只说"报告已发送"，必须附上完整内容！**

---

## 参考资料

- **配置文件**：`config.json`
- **分析模板**：`references/analysis-template.md`
- **报告模板**：`references/report-template.md`
- **web-access**：`~/.agents/skills/web-access/SKILL.md`

---

**版本历史**：
- v2.2.1：添加输出规则（查询后必须以 md 格式输出完整内容）
- v2.2.0：添加图片变化检测（URL 对比 + 截图 AI 分析）
- v2.1.0：规范报告格式、对比逻辑、动态路径
- v2.0.0：自动定时采集、历史数据保存
- v1.0.0：基础竞品监控
