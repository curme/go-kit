import Foundation

struct WuStone {
    let color: Int
    let point: Int
}

struct WuMove: Identifiable {
    let number: Int
    let color: Int
    let point: Int?
    var id: Int { number }
}

struct WuLesson: Identifiable {
    let id: Int
    let bookNumber: Int
    let title: String
    let theme: String
    let date: String
    let black: String
    let white: String
    let result: String
    let sourceStatus: String
    let setup: [WuStone]
    let moves: [WuMove]
    let focusMove: Int
    let intro: String
    let prompt: String
    let options: [String]
    let answer: Int
    let explanation: String
    let takeaway: String

    func position(after moveCount: Int) -> (board: [Int], lastPoint: Int?) {
        var board = GoEngine.empty(19)
        for stone in setup { board[stone.point] = stone.color }
        var history: Set<String> = [GoEngine.hash(board)]
        var lastPoint: Int?
        for move in moves.prefix(max(0, min(moveCount, moves.count))) {
            guard let point = move.point,
                  let played = try? GoEngine.play(board, at: point, color: move.color,
                                                  size: 19, history: history) else {
                lastPoint = nil
                continue
            }
            board = played.board
            history.insert(GoEngine.hash(board))
            lastPoint = point
        }
        return (board, lastPoint)
    }
}

struct WuLearningProgress: Codable {
    var completed: Set<Int> = []
    mutating func complete(_ id: Int) { completed.insert(id) }
    mutating func sanitize() { completed.formIntersection(Set(WuCurriculum.lessons.map(\.id))) }
}

private struct SavedWuLearning: Codable {
    var version = 1
    var progress: WuLearningProgress
}

enum WuCurriculum {
    static let storageKey = "go-kit.native-wu.v1"

    private static func point(_ sgf: String) -> Int {
        let bytes = Array(sgf.utf8)
        return (Int(bytes[1] - 97) * 19) + Int(bytes[0] - 97)
    }

    private static func setup(black: [String] = [], white: [String] = []) -> [WuStone] {
        black.map { WuStone(color: 1, point: point($0)) }
            + white.map { WuStone(color: 2, point: point($0)) }
    }

    private static func moves(_ text: String) -> [WuMove] {
        text.split(separator: " ").enumerated().map { index, token in
            let raw = String(token)
            return WuMove(number: index + 1, color: raw.first == "B" ? 1 : 2,
                          point: raw.count > 1 ? point(String(raw.dropFirst())) : nil)
        }
    }

    static let lessons: [WuLesson] = [
        WuLesson(
            id: 0, bookNumber: 1, title: "座子棋：从不同起点思考", theme: "不被固定开局束缚",
            date: "1926", black: "吴清源", white: "汪云峰", result: "黑中盘胜",
            sourceStatus: "出版社试读确认对局身份；主线棋谱来自公开历史档案",
            setup: setup(black: ["dp", "pd"], white: ["dd", "pp"]),
            moves: moves("Bqj Wnc Bpf Wjc Bcj Wch Bjq Wcl Bej Wel Bgj Wfp Bfo Weo Bep Wfq"),
            focusMove: 0,
            intro: "这是一局旧中国规则的座子棋。正式落子前，四个角已经交错摆好黑白棋。我们先观察起点，不急着模仿后续复杂变化。",
            prompt: "这局棋与现代空棋盘开局最明显的区别是什么？",
            options: ["开局前四角已经摆有黑白棋", "第一手必须下天元", "棋盘只有九路"], answer: 0,
            explanation: "棋盘开始时已有两黑两白四颗座子。不同起点会改变布局方向，也提醒我们先读当前盘面，再套用经验。",
            takeaway: "先看盘面已有条件，再决定方向；不要机械套用固定次序。"
        ),
        WuLesson(
            id: 1, bookNumber: 2, title: "少年时期：先占大处", theme: "角部与全盘",
            date: "1927-11-25", black: "吴清源", white: "井上孝平", result: "黑中盘胜",
            sourceStatus: "出版社试读确认对局身份；主线棋谱来自公开历史档案",
            setup: [], moves: moves("Bqd Wqp Bdc Wce Bco Wep Beo Wdo Bdp Wdn Bcp Weq Bfo Wcn Bgq Wcr"),
            focusMove: 4,
            intro: "前三手分别落在右上、右下和左上三个角。随后双方才在左上接触。启蒙阶段先学习这种全盘观察顺序。",
            prompt: "前三手最直接体现了什么布局习惯？",
            options: ["先看不同角部的大处", "从第一手开始连续贴一线", "只守住一颗棋不动"], answer: 0,
            explanation: "前三手分布在三个角，先取得全盘骨架，再进入局部接触。这里讲的是观察方法，不是要求背下原谱。",
            takeaway: "开局先巡视全盘大处，再决定何时进入局部战斗。"
        ),
        WuLesson(
            id: 2, bookNumber: 30, title: "木谷第二局：四角之后", theme: "先搭骨架，再展开",
            date: "1939-12-26 至 28", black: "吴清源", white: "木谷实", result: "黑中盘胜",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bpd Wdp Bpp Wdd Bfq Wdn Bjp Wqn Bql Won Bnp Wpk Bqo Wrn Bpl Wol"),
            focusMove: 8,
            intro: "前四手占据四个不同角，之后黑白开始沿边展开。先把棋盘骨架搭起来，局部选择才有全盘背景。",
            prompt: "前四手结束后，棋盘出现了什么结构？",
            options: ["四个角都已有棋子", "所有棋子挤在同一个角", "中央已经完全围住"], answer: 0,
            explanation: "四角各有一子，双方随后根据角部关系向边上展开。初学时先学会辨认这种全盘骨架。",
            takeaway: "先确认四角与边的关系，再判断哪一处最宽。"
        ),
        WuLesson(
            id: 3, bookNumber: 32, title: "木谷第四局：局部之外还有全盘", theme: "适时转向",
            date: "1940-06-12 至 14", black: "吴清源", white: "木谷实", result: "黑胜 1 目",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bpd Wcd Bpp Wdq Bed Wdc Bec Wde Bjc Wco Bjq Wqf Bnd Wrd Bqh Wqc"),
            focusMove: 9,
            intro: "前八手在取得四角后，左上出现短暂接触。黑第九手转到上边较开阔的位置，没有把每一手都挤在局部。",
            prompt: "局部暂时没有必须立即回应的危险时，应该养成什么习惯？",
            options: ["重新巡视全盘，寻找更宽的方向", "永远在原地加固", "不数气直接打入"], answer: 0,
            explanation: "本课把黑第九手作为全盘观察的例子。具体好坏需要完整分析；启蒙阶段先练习在局部之外寻找候选点。",
            takeaway: "局部告一段落，就抬头看全盘，别被上一手绑住。"
        ),
        WuLesson(
            id: 4, bookNumber: 35, title: "雁金第一局：执白也能主动", theme: "颜色不决定气势",
            date: "1941-08-07 至 09", black: "雁金准一", white: "吴清源", result: "白中盘胜",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bqd Wpp Bec Wde Bcd Wce Bdd Wee Bfd Wdq Bgf Wci Bnc Wdo Bne Wrd"),
            focusMove: 12,
            intro: "吴清源本局执白。白棋一面回应局部，一面把棋走向新的角边。后手并不等于只能被动跟随。",
            prompt: "执白时更健康的基本想法是什么？",
            options: ["只要跟着黑棋应手", "处理必要应手，同时寻找自己的主动方向", "每手都必须立即战斗"], answer: 1,
            explanation: "颜色决定先后手，却不决定谁必须一直被动。判断哪些手必须应、哪些地方可以主动，是全盘棋的重要能力。",
            takeaway: "回应威胁以后，继续寻找自己的大场和攻击方向。"
        ),
        WuLesson(
            id: 5, bookNumber: 49, title: "桥本第八局：局部结束就转身", theme: "轻灵转身",
            date: "1947-10-03", black: "桥本宇太郎", white: "吴清源", result: "白中盘胜",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bpd Wdc Bpq Wcq Bce Wpo Bqo Wpp Bqp Woq Bqn Wpr Bqq Wjq Bcj Wdg"),
            focusMove: 14,
            intro: "右下发生一串接触后，白第十四手离开原来的局部，转到下边。我们用它练习判断何时可以脱先。",
            prompt: "考虑离开局部之前，最先检查什么？",
            options: ["自己的棋是否已经安全，对方有没有强制手", "远处落点是否看起来漂亮", "棋盘上棋子是否对称"], answer: 0,
            explanation: "转身之前必须确认局部没有立即被吃或被切断的危险。确认安全后，及时走向更大的地方能提高效率。",
            takeaway: "先确认局部安全，再轻灵转向全盘更大的地方。"
        ),
        WuLesson(
            id: 6, bookNumber: 64, title: "藤泽十番棋第三局：每一点都重要", theme: "细小差距与坚持",
            date: "1951-12-22 至 24", black: "藤泽库之助", white: "吴清源", result: "和棋",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bpd Wdc Bpp Wdq Bde Wcn Bec Web Bed Wfc Bfb Wgb Bdb Wfa Bcc Wfd"),
            focusMove: 16,
            intro: "这局历史记录为和棋。启蒙阶段不分析全盘胜负，只借结果理解：官子、死活确认和每一次交换都可能影响最后的细小差距。",
            prompt: "棋谱结果中的“和棋”说明什么？",
            options: ["双方结果相同，没有分出胜负", "白棋中盘胜", "棋局没有开始"], answer: 0,
            explanation: "和棋表示最终没有分出胜负。越接近的棋，越能体现稳定检查和认真收官的重要性。",
            takeaway: "优势再小也要认真收官；落后再小也值得继续寻找机会。"
        ),
        WuLesson(
            id: 7, bookNumber: 71, title: "坂田十番棋第八局：把优势走到终局", theme: "从布局到收官",
            date: "1954-07-24 至 25", black: "吴清源", white: "坂田荣男", result: "黑胜 7 目",
            sourceStatus: "按书目标题与历史档案赛事、轮次关联",
            setup: [], moves: moves("Bqd Wnd Bpq Wpn Bcp Wqq Bdc Weq Bpf Wde Bee Wef Bed Wdg Bdo Wpp"),
            focusMove: 16,
            intro: "这局记录为黑胜 7 目。职业棋的完整胜因很复杂，本课只训练读懂结果，并把注意力放在“每个阶段都继续做正确判断”。",
            prompt: "棋谱结果“黑胜 7 目”是什么意思？",
            options: ["黑方最终领先 7 目", "黑方提了 7 颗就自动获胜", "黑方只下了 7 手"], answer: 0,
            explanation: "它表示按该局采用的规则计算后，黑方最终领先 7 目。胜负不能只用提子数解释。",
            takeaway: "从布局到官子都在积累结果；提子只是手段，最终仍要比较全局。"
        )
    ]

    static func encode(_ progress: WuLearningProgress) throws -> Data {
        try JSONEncoder().encode(SavedWuLearning(progress: progress))
    }

    static func decode(_ data: Data) throws -> WuLearningProgress {
        let saved = try JSONDecoder().decode(SavedWuLearning.self, from: data)
        guard saved.version == 1 else { return WuLearningProgress() }
        var progress = saved.progress
        progress.sanitize()
        return progress
    }
}
