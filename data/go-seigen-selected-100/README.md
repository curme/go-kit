# 《吴清源自选百局》数据

**已取得原书全部 100 个目录条目，并关联 32 份完整主线 SGF；剩余 68 局尚未可靠对应。**
这不是“完整 100 局 SGF 包”。

目录直接抓取自[后浪出版社官方店铺](https://detail.youzan.com/show/goods?alias=3f1n4cv8qnk3m&from_source=gbox_seo)，
ISBN 9787559610966。上下卷各 50 局，保留原卷内编号，另设连续编号 1–100。

- `catalog.csv`：100 个条目的书中顺序、标题、匹配状态和已关联对局资料。
- `manifest.json`：适合程序读取的目录、棋谱元信息、完整落子与来源证据。
- `sgf/`：32 局 UTF-8 SGF，只保留实战主线和对局事实，不含书中评注及分析变化。
- `validation.json`：已关联棋谱的完整规则回放报告。

## 核对程度

1. **2 局由出版社试读页确认对局身份**：第 1 局“座子棋”（1926 年，吴清源对汪云峰）；
   第 2 局“井上孝平五段”（1927-11-25）。依据书中编号、双方、日期/年份与开局落点。
2. **30 局按目录标题与历史档案赛事/轮次对应**：包含木谷、雁金、藤泽、桥本、岩本、坂田、高川的明确番棋轮次等。
   这是有依据的目录匹配，状态为 `matched_by_catalog_title_and_archive_event`，尚未逐页复核原书。
3. **68 局待识别**：`sgf_file` 为 `null`，不会用“可能是这局”的棋谱填充。

完整落子来自 [A. E. Brouwer 公开历史棋谱档案](https://homepages.cwi.nl/~aeb/go/games/games/)。
每局保留独立来源地址与原始/导出文件 SHA-256。即使身份对应，历史档案与印刷棋谱的终点、
日期记法或后半盘也可能有差异，因此不能宣称与原书逐手一致。
日期缺月日时按来源保留，不以文件名中的 `00` 伪造日期。

规则回放检查全部落子的坐标、交替手番、占点、提子、自杀和简单劫。
该检查不验证计目结果、历史真实性和原书收录关系。

`moves[].point` 是 SGF 坐标：`aa` 左上角、`ss` 右下角，空串表示停一手。
需先摆放 `properties.AB`、`properties.AW` 中的座子/让子，再按主线回放。
目前只是本地数据，没有改动 iOS 页面或把未核实条目发布给用户。

## 更新和重建

需要 Python 3.11、Pillow（本次使用 12.3.0）和 Node.js。从项目根目录运行：

```sh
python3 scripts/fetch-go-seigen.py
python3 scripts/build-go-seigen-book.py .build/research data/go-seigen-selected-100
node scripts/validate-go-seigen.mjs data/go-seigen-selected-100
```

后续需要原书中其余对局的**日期、双方或开局棋图**，才能继续完成准确匹配。
仅靠“难解的一局”“好对手”等标题无法唯一确定对局，已保留待核对状态。

此前找到的“吴清源自战百局”网站实为另一套 93 局公开选集，
单独存放于 `../go-seigen-public-93/`，**未拿来替代本书百局**。
