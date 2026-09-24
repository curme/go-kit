# 吴清源公开棋谱 93 局：不同于《自选百局》原书

**当前不能把本目录称为《吴清源自选百局》完整 100 局。**

本次找到的[公开目录](https://qjql.net/newgo/sgf_dong.asp)名为“吴清源自战百局”，
实际只列出 93 份动画棋谱，缺少公开编号 **046、047、048、049、060、061、062**。
书中第 1 局是“座子棋”，该网站编号 001 却是 1939 年吴清源对木谷实。
匹配出的对局集中在 1939–1962 年，缺少原书开头的早年对局。
因此这是不同的公开选集，网站编号与书中编号不能直接对应。
书目参照：[三民书店](https://www.sanmin.com.tw/product/index/006563306)。

这里保存的是这 93 份公开记录对应的**候选棋谱**。不以其他对局补齐缺号，
`book_number` 保持空值，`book_membership` 保持 `unverified`。

## 文件

- `manifest.json`：逐局来源、SHA-256、棋谱属性、落子、识别证据和书目核对状态。
- `games.csv`：方便人工核对的对局清单。
- `sgf/`：从 [A. E. Brouwer 的公开历史棋谱档案](https://homepages.cwi.nl/~aeb/go/games/games/)提取的实战主线。
- `validation.json`：完整 SGF 主线的规则回放结果。

动画通过前 30 手、8 种棋盘旋转/镜像与历史档案匹配，只有唯一候选才导出 SGF。
完整落子采用 CWI 档案，**不是把动画全部转换后未经检查地当成原书棋谱**。
部分动画额外进行了全盘比对，结果保存在 `additional_full_gif_comparison`；
其中存在双方手数、后半盘落子不同的记录。差异不自动视为某一来源错误。
其余动画只核对开局，不能把 `identified_by_30_move_prefix` 解读为逐手一致。

回放检查坐标、轮流落子、重复占点、提子、自杀和简单劫。
通过回放不代表对局历史信息、记谱终点、胜负目数或书目归属均已核实。
日期、棋手名、结果按历史档案保留；日期不完整时不猜测月日。
数据不包含书中评注、分析变化和版面图片。当前未接入 iOS 界面。

JSON 中 `point` 使用 SGF 坐标，`aa` 为左上角，`ss` 为右下角；空串为停一手。
开局座子/让子在 `properties.AB`、`properties.AW` 中，回放时需要先摆放。

## 重建

需要 Python 3.11、Pillow 和 Node.js，在项目根目录执行：

```sh
python3 scripts/fetch-go-seigen.py
python3 scripts/extract-go-seigen.py .build/research
python3 scripts/build-go-seigen-data.py .build/research data/go-seigen-public-93
node scripts/validate-go-seigen.mjs data/go-seigen-public-93
```

网络获取与临时动画、完整历史档案放在忽略提交的 `.build/research/`。
可在虚拟环境安装 `Pillow==12.3.0`；不会改变 iOS 或网页项目依赖。
额外全盘抽查来自本次研究缓存 `full-comparison-sample.json`，重新只跑前 30 手
流程不会生成全盘抽查；发布包中的记录保留本次已完成抽查的结果。

## 尚需补齐

需要可核对到具体对局日期/对手的**原书 100 局目录或对应棋谱来源**，
才能建立可靠的 `book_number` 映射并判断哪些书中对局尚缺。
公开网站的七个缺号不等于已确认原书恰好只缺七局。
