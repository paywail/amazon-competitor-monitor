# Amazon Competitor Monitor Skill

亚马逊竞品监控与分析 Skill - 自动采集竞品数据并生成周报

## 功能

- 🔄 **自动采集**：使用 web-access CDP 模式采集亚马逊商品详情数据
- 📊 **数据分析**：AI 分析竞品价格/促销/卖点变动并评估影响等级
- 📝 **周报生成**：输出一页式竞品监控周报

## 采集数据字段

- ASIN、标题、售价、划线价、优惠券
- 评分、评论数、五点卖点
- Prime 支持、BSR 排名

## 使用方法

### 1. 安装

将此 skill 放入 `~/.agents/skills/` 目录：

```bash
git clone https://github.com/paywail/amazon-competitor-monitor.git ~/.agents/skills/amazon-competitor-monitor
```

### 2. 触发 Skill

对 AI 说：
- "帮我监控亚马逊日本站桌子类目搜索页前5名竞品"
- "分析这些竞品：B01G4JMQFW, B0BB676W8L, B092CVMP7K"
- "帮我生成竞品监控周报"

### 3. 核心流程

```
1. 确定监控对象（搜索页URL / BS榜单URL / ASIN列表）
2. 启动 web-access CDP 采集数据
3. 按分析模板进行 AI 分析
4. 按周报模板输出报告
```

## 文件结构

```
amazon-competitor-monitor/
├── SKILL.md                 # 核心流程指引
├── scripts/
│   └── fetch_competitors.sh # CDP 数据采集脚本
└── references/
│   ├── analysis-template.md # AI 分析模板
│   └── report-template.md   # 周报输出模板
```

## 支持站点

- 日本站：amazon.co.jp
- 美国站：amazon.com
- 其他亚马逊站点

## 依赖

- web-access skill（CDP 模式）
- Chrome 浏览器

## 作者

Created by AI Assistant

## License

MIT
