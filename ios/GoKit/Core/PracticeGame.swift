import Foundation

struct PracticeTurn: Codable, Equatable, Identifiable {
    let ply: Int
    let color: Int
    let point: Int
    let board: [Int]
    let captured: [Int]
    var id: Int { ply }
}

struct GamePosition: Codable {
    var board = GoEngine.empty(9)
    var history: Set<String> = [GoEngine.hash(GoEngine.empty(9))]
    var captures = [0, 0]
    var moves = 0
    var lastPoint: Int?
    var paused = false
    var message = "你执黑，先行。先在三线附近试着落子，给棋子留出发展的空间。"
    var turns: [PracticeTurn] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case board, history, captures, moves, lastPoint, paused, message, turns
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        board = try values.decode([Int].self, forKey: .board)
        history = try values.decode(Set<String>.self, forKey: .history)
        captures = try values.decode([Int].self, forKey: .captures)
        moves = try values.decode(Int.self, forKey: .moves)
        lastPoint = try values.decodeIfPresent(Int.self, forKey: .lastPoint)
        paused = try values.decode(Bool.self, forKey: .paused)
        message = try values.decode(String.self, forKey: .message)
        turns = try values.decodeIfPresent([PracticeTurn].self, forKey: .turns) ?? []
    }
}

struct PracticeGame: Codable {
    var position = GamePosition()
    var undoPositions: [GamePosition] = []
    static let size = 9

    mutating func play(_ point: Int) throws {
        guard !position.paused else { return }
        let black = try GoEngine.play(position.board, at: point, color: 1, size: 9, history: position.history)
        saveUndo()
        apply(black, point: point, color: 1)
        if let white = GoEngine.chooseMove(position.board, color: 2, size: 9, history: position.history) {
            apply(white.move, point: white.point, color: 2)
            position.message = white.reason
        } else {
            position.moves += 1; position.lastPoint = nil
            position.message = "白棋停一手。你可以继续落子，或者停一手检查死活与边界。"
        }
    }
    mutating func apply(_ move: GoMove, point: Int, color: Int) {
        position.board = move.board
        position.history.insert(GoEngine.hash(move.board))
        position.captures[color - 1] += move.captured.count
        position.moves += 1; position.lastPoint = point
        position.turns.append(PracticeTurn(ply: position.moves, color: color, point: point,
                                           board: move.board, captured: move.captured))
    }
    mutating func saveUndo() {
        undoPositions.append(position)
        if undoPositions.count > 30 { undoPositions.removeFirst() }
    }
    mutating func pass() {
        guard !position.paused else { return }
        saveUndo()
        position.moves += 2; position.paused = true; position.lastPoint = nil
        position.message = "你停一手，陪练也停一手，本轮练习暂停。估算没有移除死子，不能作为最终胜负；检查后可以继续下棋。"
    }
    mutating func resume() {
        position.paused = false
        position.message = "继续练习。先看看边界有没有封住，有没有棋需要补活。"
    }
    mutating func undo() {
        guard let previous = undoPositions.popLast() else { return }
        position = previous
        position.message = "退回到你上一手之前。换个落点，会发生什么？"
    }

    mutating func retry(beforeTurn index: Int) {
        guard position.turns.indices.contains(index) else { return }
        let prefix = Array(position.turns.prefix(index))
        var next = GamePosition()
        next.board = prefix.last?.board ?? GoEngine.empty(Self.size)
        next.history = Set([GoEngine.hash(GoEngine.empty(Self.size))] + prefix.map { GoEngine.hash($0.board) })
        next.captures = [
            prefix.filter { $0.color == 1 }.reduce(0) { $0 + $1.captured.count },
            prefix.filter { $0.color == 2 }.reduce(0) { $0 + $1.captured.count }
        ]
        next.moves = prefix.last?.ply ?? 0
        next.lastPoint = prefix.last?.point
        next.turns = prefix
        next.message = "已经回到第 \(position.turns[index].ply) 手之前。先检查双方的气，再试试教练标出的方向。"
        position = next
        undoPositions = []
    }
}

enum ReviewTheme: String {
    case rescue = "先救危险棋"
    case capture = "别错过提子"
    case selfAtari = "给自己多留气"
    case opening = "开局走得舒展"
    case goodCapture = "抓住了机会"
    case goodRescue = "处理得很稳"
    case reflection = "回看这一手"
}

struct ReviewInsight: Identifiable {
    let turnIndex: Int
    let ply: Int
    let theme: ReviewTheme
    let boardBefore: [Int]
    let playedPoint: Int
    let recommendedPoint: Int?
    let explanation: String
    let priority: Int
    var id: String { "\(ply)-\(theme.rawValue)" }
}

enum PracticeReviewer {
    static func insights(for position: GamePosition) -> [ReviewInsight] {
        var urgent: [ReviewInsight] = []
        var advice: [ReviewInsight] = []
        var praise: [ReviewInsight] = []

        for (index, turn) in position.turns.enumerated() where turn.color == 1 {
            let before = index == 0 ? GoEngine.empty(PracticeGame.size) : position.turns[index - 1].board
            let endangered = groups(on: before, color: 1).filter { $0.liberties.count == 1 }
            let capturable = groups(on: before, color: 2).filter { $0.liberties.count == 1 }

            if let group = endangered.first(where: { group in
                guard let liberty = group.liberties.first else { return false }
                return turn.point != liberty && turn.captured.isEmpty
            }), let liberty = group.liberties.first {
                urgent.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .rescue,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: liberty,
                    explanation: "落子前有一块黑棋只剩一口气。优先在 \(GoEngine.coordinate(liberty, size: 9)) 延长气；如果附近能提子或连接，也要先算清楚。",
                    priority: 3))
                continue
            }

            if let group = capturable.first(where: { group in
                guard let liberty = group.liberties.first else { return false }
                return turn.point != liberty
            }), let liberty = group.liberties.first {
                urgent.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .capture,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: liberty,
                    explanation: "白棋已经只剩最后一口气。下在 \(GoEngine.coordinate(liberty, size: 9)) 可以立即提子，实战中应先检查这种强制机会。",
                    priority: 3))
                continue
            }

            let playedGroup = GoEngine.group(turn.board, at: turn.point, size: 9)
            if playedGroup.liberties.count == 1 && turn.captured.isEmpty {
                let alternatives = legalSafeMoves(on: before)
                advice.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .selfAtari,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: alternatives.first,
                    explanation: "这手下完后，新棋块只剩一口气，容易立刻被打吃。选择气更多的落点，通常会更稳。",
                    priority: 2))
                continue
            }

            let edge = min(turn.point % 9, turn.point / 9, 8 - turn.point % 9, 8 - turn.point / 9)
            if turn.ply <= 9 && edge == 0 && turn.captured.isEmpty {
                let corners = [20, 24, 56, 60].filter { before[$0] == 0 }
                advice.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .opening,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: corners.first,
                    explanation: "开局太早贴着一线走，发展空间会比较小。九路棋先从三线附近的角部展开，更容易同时照顾地盘和出路。",
                    priority: 1))
                continue
            }

            if !turn.captured.isEmpty {
                praise.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .goodCapture,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: turn.point,
                    explanation: "你看到了对方的最后一口气，这手提掉了 \(turn.captured.count) 颗白子。继续保持“先看气、再落子”的顺序。",
                    priority: 0))
            } else if let saved = endangered.first,
                      let liberty = saved.liberties.first, turn.point == liberty,
                      GoEngine.group(turn.board, at: turn.point, size: 9).liberties.count > 1 {
                praise.append(ReviewInsight(turnIndex: index, ply: turn.ply, theme: .goodRescue,
                    boardBefore: before, playedPoint: turn.point, recommendedPoint: turn.point,
                    explanation: "你及时处理了只剩一口气的黑棋，并让它重新获得空间。这是很重要的实战习惯。",
                    priority: 0))
            }
        }

        var result = Array(urgent.prefix(3))
        result.append(contentsOf: advice.prefix(max(0, 5 - result.count)))
        result.append(contentsOf: praise.prefix(max(0, 5 - result.count)))
        if result.isEmpty, let index = position.turns.firstIndex(where: { $0.color == 1 }) {
            let turn = position.turns[index]
            let before = index == 0 ? GoEngine.empty(9) : position.turns[index - 1].board
            result = [ReviewInsight(turnIndex: index, ply: turn.ply, theme: .reflection,
                boardBefore: before, playedPoint: turn.point, recommendedPoint: nil,
                explanation: "这盘没有发现明确的吃子或气紧错误。回看这一手时，继续问自己：有没有危险棋、有没有对方弱棋、能不能走得更舒展？",
                priority: 0)]
        }
        return result.sorted { $0.ply < $1.ply }
    }

    private static func groups(on board: [Int], color: Int) -> [GoGroup] {
        var seen: Set<Int> = []
        var result: [GoGroup] = []
        for point in board.indices where board[point] == color && !seen.contains(point) {
            let group = GoEngine.group(board, at: point, size: 9)
            seen.formUnion(group.stones)
            result.append(group)
        }
        return result
    }

    private static func legalSafeMoves(on board: [Int]) -> [Int] {
        let ranked: [(point: Int, score: Int)] = board.indices.compactMap { point -> (point: Int, score: Int)? in
            guard let move = try? GoEngine.play(board, at: point, color: 1, size: 9),
                  move.liberties.count >= 2 else { return nil }
            let edge = min(point % 9, point / 9, 8 - point % 9, 8 - point / 9)
            return (point: point, score: move.liberties.count * 10 + min(edge, 2))
        }
        return ranked.sorted { $0.score > $1.score }.map(\.point)
    }
}
