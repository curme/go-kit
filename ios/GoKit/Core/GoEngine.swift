import Foundation

enum GoError: Error, LocalizedError {
    case occupied, suicide, repetition, invalidPoint
    var errorDescription: String? {
        switch self {
        case .occupied: return "这里已经有棋子了，请选择空交叉点。"
        case .suicide: return "这手没有气，也不能提掉对方棋子，属于禁入点。"
        case .repetition: return "这手会重复先前的盘面。劫不能立即回提，要先在别处改变局面。"
        case .invalidPoint: return "请落在棋盘的交叉点上。"
        }
    }
}

struct GoGroup {
    var stones: Set<Int>
    var liberties: Set<Int>
}

struct GoMove {
    let board: [Int]
    let captured: [Int]
    let liberties: Set<Int>
}

struct AreaEstimate {
    var black = 0
    var white = 0
    var neutral = 0
    var territory: [Int]
}

struct BotMove {
    let point: Int
    let move: GoMove
    let reason: String
    let score: Double
}

enum GoEngine {
    static func empty(_ size: Int) -> [Int] { Array(repeating: 0, count: size * size) }
    static func hash(_ board: [Int]) -> String { board.map(String.init).joined() }
    static func coordinate(_ point: Int, size: Int) -> String {
        let letters = Array("ABCDEFGHJKLMNOPQRST")
        return "\(letters[point % size])\(size - point / size)"
    }
    static func neighbors(_ point: Int, size: Int) -> [Int] {
        let x = point % size, y = point / size
        return [x > 0 ? point - 1 : -1, x < size - 1 ? point + 1 : -1,
                y > 0 ? point - size : -1, y < size - 1 ? point + size : -1].filter { $0 >= 0 }
    }
    static func group(_ board: [Int], at point: Int, size: Int) -> GoGroup {
        guard board.indices.contains(point), board[point] != 0 else {
            return GoGroup(stones: [], liberties: [])
        }
        var stones: Set<Int> = [point], liberties: Set<Int> = [], queue = [point], cursor = 0
        while cursor < queue.count {
            let p = queue[cursor]; cursor += 1
            for q in neighbors(p, size: size) {
                if board[q] == 0 { liberties.insert(q) }
                else if board[q] == board[point], stones.insert(q).inserted { queue.append(q) }
            }
        }
        return GoGroup(stones: stones, liberties: liberties)
    }
    static func play(_ board: [Int], at point: Int, color: Int, size: Int,
                     history: Set<String> = []) throws -> GoMove {
        guard size > 1, board.count == size * size, board.indices.contains(point),
              color == 1 || color == 2 else { throw GoError.invalidPoint }
        guard board[point] == 0 else { throw GoError.occupied }
        var next = board, captured: [Int] = []
        next[point] = color
        for q in neighbors(point, size: size) where next[q] == 3 - color {
            let enemy = group(next, at: q, size: size)
            if enemy.liberties.isEmpty {
                for p in enemy.stones { next[p] = 0; captured.append(p) }
            }
        }
        let own = group(next, at: point, size: size)
        guard !own.liberties.isEmpty else { throw GoError.suicide }
        guard !history.contains(hash(next)) else { throw GoError.repetition }
        return GoMove(board: next, captured: captured.sorted(), liberties: own.liberties)
    }
    static func estimate(_ board: [Int], size: Int) -> AreaEstimate {
        var result = AreaEstimate(territory: empty(size)), seen: Set<Int> = []
        result.black = board.filter { $0 == 1 }.count
        result.white = board.filter { $0 == 2 }.count
        for i in board.indices where board[i] == 0 && !seen.contains(i) {
            var region = [i], boundary: Set<Int> = [], cursor = 0
            seen.insert(i)
            while cursor < region.count {
                let p = region[cursor]; cursor += 1
                for q in neighbors(p, size: size) {
                    if board[q] != 0 { boundary.insert(board[q]) }
                    else if seen.insert(q).inserted { region.append(q) }
                }
            }
            let owner = boundary.count == 1 ? boundary.first! : 0
            for p in region { result.territory[p] = owner }
            if owner == 1 { result.black += region.count }
            else if owner == 2 { result.white += region.count }
            else { result.neutral += region.count }
        }
        return result
    }
    static func chooseMove(_ board: [Int], color: Int, size: Int, history: Set<String>) -> BotMove? {
        var best: BotMove?, seen: Set<Int> = [], endangered: [GoGroup] = []
        for i in board.indices where board[i] == color && !seen.contains(i) {
            let own = group(board, at: i, size: size)
            seen.formUnion(own.stones)
            if own.liberties.count == 1 { endangered.append(own) }
        }
        for i in board.indices where board[i] == 0 {
            guard let move = try? play(board, at: i, color: color, size: size, history: history) else { continue }
            let adjacent = neighbors(i, size: size)
            if adjacent.allSatisfy({ board[$0] == color }) && move.captured.isEmpty { continue }
            let rescue = endangered.filter { $0.liberties.contains(i) && move.liberties.count > 1 }
                .reduce(0) { $0 + $1.stones.count }
            var threats: Set<Int> = []
            for p in adjacent where move.board[p] == 3 - color {
                let enemy = group(move.board, at: p, size: size)
                if enemy.liberties.count == 1, let first = enemy.stones.min() { threats.insert(first) }
            }
            let x = i % size, y = i / size
            let edge = min(x, y, size - 1 - x, size - 1 - y)
            let distance = board.indices.filter { board[$0] != 0 }.map {
                abs($0 % size - x) + abs($0 / size - y)
            }.min() ?? size
            var score = Double(move.captured.count * 18 + rescue * 15 + threats.count * 5)
            score += Double(min(move.liberties.count, 4) + (edge == 2 ? 3 : edge == 1 ? 1 : 0))
            score += Double(distance == 2 ? 2 : 0) - Double(move.liberties.count == 1 ? 22 : 0)
            score -= Double(adjacent.filter { board[$0] == color }.count) * 0.7
            score += Double((i * 17) % 13) / 100
            let reason: String
            if !move.captured.isEmpty { reason = "白棋提掉了 \(move.captured.count) 颗黑子。回头看看，哪块棋刚才只剩最后一口气？" }
            else if rescue > 0 { reason = "白棋正在逃出打吃。只剩一口气时，先考虑延长气、连接或提子。" }
            else if !threats.isEmpty { reason = "白棋形成了打吃。检查你的棋，找到只剩一口气的那一块。" }
            else { reason = "白棋在拓展空间。轮到你：先检查双方的气，再考虑连接和围地。" }
            if best == nil || score > best!.score { best = BotMove(point: i, move: move, reason: reason, score: score) }
        }
        return best.flatMap { $0.score > -5 ? $0 : nil }
    }
}
