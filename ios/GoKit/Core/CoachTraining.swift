import Foundation

enum TrainingSkill: String, Codable, CaseIterable {
    case liberties = "数气", capture = "提子", rescue = "救棋", connect = "连接"
}

struct TrainingProblem: Identifiable {
    let id: String
    let title: String
    let skill: TrainingSkill
    let board: [Int]
    let focus: [Int]
    let prompt: String
    let hint: String
    var options: [Int] = []
    let size = 5

    var group: GoGroup { GoEngine.group(board, at: focus[0], size: size) }
    func accepts(_ move: GoMove, at point: Int) -> Bool {
        switch skill {
        case .liberties: return false
        case .capture: return Set(focus).isSubset(of: Set(move.captured))
        case .rescue:
            let saved = GoEngine.group(move.board, at: focus[0], size: size)
            return focus.allSatisfy { move.board[$0] == 1 }
                && saved.stones.contains(point) && saved.liberties.count >= 2
        case .connect:
            let joined = GoEngine.group(move.board, at: point, size: size)
            return Set(focus).isSubset(of: joined.stones) && joined.liberties.count >= 2
        }
    }
    var solutions: Set<Int> {
        Set(board.indices.filter { point in
            guard let move = try? GoEngine.play(board, at: point, color: 1, size: size) else { return false }
            return accepts(move, at: point)
        })
    }
}

enum CoachCurriculum {
    static func board(black: [Int], white: [Int]) -> [Int] {
        var result = GoEngine.empty(5)
        for p in black { result[p] = 1 }
        for p in white { result[p] = 2 }
        return result
    }
    static let problems: [TrainingProblem] = [
        TrainingProblem(id: "count-center", title: "先数清呼吸", skill: .liberties,
            board: board(black: [12], white: [7]), focus: [12],
            prompt: "标出的黑子有几口气？", hint: "只看上下左右。上方是白子，其余相邻空点各算一口气。", options: [2, 3, 4]),
        TrainingProblem(id: "count-edge", title: "棋盘边上少一边", skill: .liberties,
            board: board(black: [10], white: [5]), focus: [10],
            prompt: "左边这颗黑子有几口气？", hint: "棋盘外不算气，上方白子也不算。看看右边和下边。", options: [1, 2, 3]),
        TrainingProblem(id: "count-group", title: "整块棋一起数", skill: .liberties,
            board: board(black: [11, 12], white: [6]), focus: [11, 12],
            prompt: "相连的两颗黑子，一共有几口不同的气？", hint: "绕整块黑棋数相邻空点。棋子本身不算气，同一个空点只数一次。", options: [4, 5, 6]),
        TrainingProblem(id: "capture-one", title: "封住最后一口气", skill: .capture,
            board: board(black: [7, 11, 17], white: [12]), focus: [12],
            prompt: "你执黑，下一手提掉中间的白子。", hint: "白子只剩右侧 D3 一口气。"),
        TrainingProblem(id: "capture-pair", title: "一次提走整块", skill: .capture,
            board: board(black: [1, 2, 5, 8, 11], white: [6, 7]), focus: [6, 7],
            prompt: "你执黑，下一手提掉相连的两颗白子。", hint: "把两颗白子当作一整块。它们只剩 C3 一口气。"),
        TrainingProblem(id: "capture-corner", title: "角上的提子", skill: .capture,
            board: board(black: [1], white: [0]), focus: [0],
            prompt: "你执黑，提掉左上角的白子。", hint: "角上只有两个相邻点，右边已经封住，试试下方 A4。"),
        TrainingProblem(id: "rescue-one", title: "先救自己的棋", skill: .rescue,
            board: board(black: [12], white: [7, 11, 17]), focus: [12],
            prompt: "黑子被叫吃了。下一手让它至少有两口气。", hint: "沿最后一口气 D3 向外长，连成一块后重新数气。"),
        TrainingProblem(id: "rescue-corner", title: "从角上跑出来", skill: .rescue,
            board: board(black: [0], white: [1]), focus: [0],
            prompt: "救出左上角黑子，让它至少有两口气。", hint: "向下走到 A4，就能接触更多空点。"),
        TrainingProblem(id: "connect-center", title: "两颗棋牵起手", skill: .connect,
            board: board(black: [11, 13], white: [6, 8]), focus: [11, 13],
            prompt: "下一手把两颗黑子连成一块，并保留至少两口气。", hint: "填上两颗黑子之间的 C3，它们就能共享气。"),
        TrainingProblem(id: "connect-edge", title: "在边上连接", skill: .connect,
            board: board(black: [0, 2], white: [5, 7]), focus: [0, 2],
            prompt: "下一手连接上方两颗黑子，并保留至少两口气。", hint: "在两颗黑子之间的 B5 落子，再数整块棋的气。")
    ]
    static let guidedIDs = ["count-center", "capture-one", "rescue-one"]
    static func problem(_ id: String) -> TrainingProblem? { problems.first { $0.id == id } }
}

struct TrainingAttempt {
    let problem: TrainingProblem
    private(set) var board: [Int]
    private(set) var solved = false
    private(set) var usedHint = false
    private(set) var madeMistake = false
    private(set) var needsRetry = false
    private(set) var feedback: String
    private(set) var marked: Set<Int>
    private(set) var liberties: Set<Int> = []
    private(set) var lastPoint: Int?
    private(set) var demonstration: GoMove?
    private(set) var demonstrationPoint: Int?
    private(set) var demonstrated = false
    var independent: Bool { solved && !usedHint && !madeMistake }

    init(_ problem: TrainingProblem) {
        self.problem = problem; board = problem.board; marked = Set(problem.focus)
        feedback = problem.skill == .liberties ? "先自己数一数，再选择答案。" : "先选一个点，再确认落子。"
    }
    mutating func help() {
        guard !solved, !needsRetry else { return }
        usedHint = true; feedback = problem.hint
        liberties = problem.skill == .liberties ? problem.group.liberties : problem.solutions
    }
    mutating func answer(_ count: Int) {
        guard !solved, !needsRetry, problem.skill == .liberties else { return }
        if count == problem.group.liberties.count {
            solved = true; liberties = problem.group.liberties
            feedback = "答对了！这块棋有 \(count) 口气。上下左右的相邻空点才算气，连在一起的棋共享气。"
        } else {
            madeMistake = true; needsRetry = true; liberties = problem.group.liberties
            feedback = "这块棋实际有 \(problem.group.liberties.count) 口气，已在棋盘上圈出。沿整块棋数一遍，再重新作答。"
        }
    }
    mutating func play(_ point: Int) {
        guard !solved, !needsRetry, problem.skill != .liberties else { return }
        do {
            let move = try GoEngine.play(problem.board, at: point, color: 1, size: problem.size)
            board = move.board; lastPoint = point; liberties = []
            if problem.accepts(move, at: point) {
                solved = true; marked = GoEngine.group(board, at: point, size: 5).stones
                liberties = move.liberties
                switch problem.skill {
                case .capture: feedback = "提掉了 \(move.captured.count) 颗白子！你占住了整块白棋最后一口气，所以它们一起离开棋盘。"
                case .rescue: feedback = "救出来了！相连的黑棋现在有 \(move.liberties.count) 口气，对方不能一手提走这一块。"
                case .connect: feedback = "连上了！这块黑棋共享 \(move.liberties.count) 口气。记住：斜着挨在一起不算连接。"
                case .liberties: break
                }
            } else {
                madeMistake = true; needsRetry = true
                feedback = problem.skill == .capture ? "这手没有提掉目标白棋。先找它最后一口气。" :
                    problem.skill == .connect ? "这手还没有把目标黑棋连成一块并留下两口气。看看它们之间的空点。" :
                    "这手还没有救出目标黑棋。被叫吃时，先照顾只剩一口气的那一块。"
                prepareDemonstration()
            }
        } catch {
            madeMistake = true; needsRetry = true; feedback = error.localizedDescription
        }
    }
    private mutating func prepareDemonstration() {
        // Explain only a forced, legal one-move capture; do not invent a strategic evaluation.
        let candidates = problem.focus.filter { board[$0] == 1 } + (lastPoint.map { [$0] } ?? [])
        for p in candidates {
            let group = GoEngine.group(board, at: p, size: 5)
            if group.liberties.count == 1, let q = group.liberties.first,
               let response = try? GoEngine.play(board, at: q, color: 2, size: 5,
                    history: [GoEngine.hash(problem.board), GoEngine.hash(board)]),
               !group.stones.isDisjoint(with: Set(response.captured)) {
                marked = group.stones; liberties = group.liberties
                demonstration = response; demonstrationPoint = q
                feedback += " 标出的 \(group.stones.count) 颗黑子只剩一口气；白棋走 \(GoEngine.coordinate(q, size: 5)) 就能提走它们。"
                return
            }
        }
        marked = Set(problem.focus); liberties = problem.group.liberties.filter { board[$0] == 0 }
    }
    mutating func demonstrate() {
        guard needsRetry, !demonstrated, let response = demonstration else { return }
        board = response.board; lastPoint = demonstrationPoint; marked = []; liberties = []
        demonstrated = true
        feedback = "白棋提走了 \(response.captured.count) 颗黑子。现在回到题目，先救那块只剩一口气的棋。"
    }
    mutating func retry() {
        // A same-attempt retry never erases hint/error history or awards independent mastery.
        guard needsRetry else { return }
        board = problem.board; marked = Set(problem.focus); liberties = []; lastPoint = nil
        demonstration = nil; demonstrationPoint = nil; demonstrated = false; needsRetry = false
        feedback = "再试一次。之后换一轮独立答对，才会移出待巩固。"
    }
}

struct TrainingProgress: Codable {
    var guidedCompleted = false
    var mastered: Set<String> = []
    var review: Set<String> = []
    mutating func record(_ attempt: TrainingAttempt) {
        let id = attempt.problem.id
        if attempt.usedHint || attempt.madeMistake { review.insert(id); mastered.remove(id) }
        if attempt.independent { mastered.insert(id); review.remove(id) }
    }
    var queue: [TrainingProblem] {
        CoachCurriculum.problems.sorted {
            func rank(_ p: TrainingProblem) -> Int { review.contains(p.id) ? 0 : mastered.contains(p.id) ? 2 : 1 }
            return rank($0) == rank($1) ? index($0) < index($1) : rank($0) < rank($1)
        }
    }
    private func index(_ p: TrainingProblem) -> Int { CoachCurriculum.problems.firstIndex { $0.id == p.id } ?? 0 }
    mutating func sanitize() {
        let ids = Set(CoachCurriculum.problems.map(\.id))
        mastered.formIntersection(ids); review.formIntersection(ids); mastered.subtract(review)
    }
}

enum CaptureOutcome: String, Codable { case playing, won, lost, draw }
struct CapturePosition: Codable {
    var board = GoEngine.empty(5)
    var history: Set<String> = [GoEngine.hash(GoEngine.empty(5))]
    var moves = 0
    var consecutivePasses = 0
    var outcome = CaptureOutcome.playing
    var lastPoint: Int?
    var message = "你执黑先行。先吃到对方棋子就赢，每手先检查双方的气。"
    var highlighted: Set<Int> = []
    var liberties: Set<Int> = []
    var isValid: Bool {
        board.count == 25 && board.allSatisfy { (0...2).contains($0) }
        && (0...80).contains(moves) && (0...2).contains(consecutivePasses)
        && (lastPoint == nil || (0..<25).contains(lastPoint!))
        && history.contains(GoEngine.hash(board))
        && history.count <= 81
        && history.allSatisfy { $0.count == 25 && $0.allSatisfy { $0 == "0" || $0 == "1" || $0 == "2" } }
        && (outcome != .playing || (moves < 80 && consecutivePasses < 2))
        && highlighted.allSatisfy { (0..<25).contains($0) }
        && liberties.allSatisfy { (0..<25).contains($0) }
    }
}
struct CaptureGame: Codable {
    private(set) var position = CapturePosition()
    private(set) var undoPositions: [CapturePosition] = []
    var isValid: Bool { position.isValid && undoPositions.count <= 30 && undoPositions.allSatisfy(\.isValid) }
    mutating func play(_ point: Int) throws {
        guard position.outcome == .playing else { return }
        let move = try GoEngine.play(position.board, at: point, color: 1, size: 5, history: position.history)
        remember(); apply(move, at: point, color: 1)
        if position.outcome == .playing { reply() }
    }
    mutating func pass() {
        guard position.outcome == .playing else { return }
        remember(); position.moves += 1; position.consecutivePasses += 1
        if !finishDraw() { reply() }
    }
    mutating func undo() { if let old = undoPositions.popLast() { position = old } }
    private mutating func remember() {
        undoPositions.append(position)
        if undoPositions.count > 30 { undoPositions.removeFirst() }
    }
    private mutating func apply(_ move: GoMove, at point: Int, color: Int) {
        position.board = move.board; position.history.insert(GoEngine.hash(move.board))
        position.lastPoint = point; position.moves += 1; position.consecutivePasses = 0
        position.highlighted = []; position.liberties = []
        if !move.captured.isEmpty {
            position.outcome = color == 1 ? .won : .lost
            let coordinates = move.captured.map { GoEngine.coordinate($0, size: 5) }.joined(separator: "、")
            position.message = color == 1 ? "挑战成功！你封住了最后一口气，提掉 \(move.captured.count) 颗白子（\(coordinates)）。" :
                "白棋先提掉了 \(move.captured.count) 颗黑子（\(coordinates)）。点「撤回一轮」回看：落子前，它们是不是只剩一口气？"
        } else { _ = finishDraw() }
    }
    private mutating func finishDraw() -> Bool {
        guard position.moves >= 80 || position.consecutivePasses >= 2 else { return false }
        position.outcome = .draw
        position.message = position.moves >= 80 ? "本局达到 80 手练习上限，和局。可以重新开局，再练寻找最后一口气。" : "双方连续停一手，本局和局。"
        return true
    }
    private mutating func reply() {
        // In capture Go any capture wins, even if the capturing group has only one liberty.
        // Ordinary Go's self-atari penalty must not outweigh an immediate win here.
        var response: (point: Int, move: GoMove)?
        for point in position.board.indices where position.board[point] == 0 {
            if let move = try? GoEngine.play(position.board, at: point, color: 2, size: 5, history: position.history),
               !move.captured.isEmpty {
                response = (point, move); break
            }
        }
        if response == nil, let bot = GoEngine.chooseMove(position.board, color: 2, size: 5, history: position.history) {
            response = (bot.point, bot.move)
        }
        if let bot = response {
            apply(bot.move, at: bot.point, color: 2)
            if position.outcome == .playing {
                position.message = "白棋走在 \(GoEngine.coordinate(bot.point, size: 5))。轮到你：先找白棋最后一口气，再检查自己的棋是否安全。"
                for p in position.board.indices where position.board[p] == 1 {
                    let group = GoEngine.group(position.board, at: p, size: 5)
                    if group.liberties.count == 1 {
                        position.highlighted.formUnion(group.stones); position.liberties.formUnion(group.liberties)
                    }
                }
                if !position.highlighted.isEmpty {
                    position.message = "标出的黑棋正在被叫吃！每块只剩一口气。先想怎样逃出、连接，或者提掉对方。"
                }
            }
        } else {
            position.moves += 1; position.consecutivePasses += 1
            position.message = "白棋停了一手。轮到你，继续找可以提子的机会。"
            _ = finishDraw()
        }
    }
}

struct SavedCoach: Codable {
    var version = 1
    var progress = TrainingProgress()
    var capture = CaptureGame()
}
