import Foundation

struct StudyTurn: Codable {
    var board: [Int]
    var color: Int
    var point: Int?
}

struct StudyPractice: Codable {
    var size = 9
    var board = GoEngine.empty(9)
    var turn = 1
    var passes = 0
    var turns: [StudyTurn] = []
    var dead: Set<Int> = []
    var confirmed = false
    var reflection = ""
    var history: Set<String> { Set([GoEngine.hash(GoEngine.empty(size))] + turns.map { GoEngine.hash($0.board) }) }
    var paused: Bool { passes >= 2 }
    var score: AreaEstimate {
        var living = board
        for p in dead where living.indices.contains(p) { living[p] = 0 }
        return GoEngine.estimate(living, size: size)
    }
    var isValid: Bool {
        [9,13,19].contains(size) && board.count == size * size && board.allSatisfy { (0...2).contains($0) }
        && (1...2).contains(turn) && (0...2).contains(passes) && turns.count <= 1200
        && dead.allSatisfy { board.indices.contains($0) && board[$0] != 0 }
        && turns.allSatisfy { $0.board.count == size * size && $0.board.allSatisfy { (0...2).contains($0) }
            && (1...2).contains($0.color) && ($0.point == nil || (0..<size*size).contains($0.point!)) }
        && (turns.last?.board ?? GoEngine.empty(size)) == board
    }
    init(size: Int = 9) {
        self.size = [9,13,19].contains(size) ? size : 9
        self.board = GoEngine.empty(self.size)
    }
    mutating func play(_ point: Int) throws {
        guard !paused, turns.count < 1200 else { return }
        board = try GoEngine.play(board, at: point, color: turn, size: size, history: history).board
        turns.append(StudyTurn(board: board, color: turn, point: point))
        turn = 3 - turn; passes = 0; dead = []; confirmed = false
    }
    mutating func pass() {
        guard !paused, turns.count < 1200 else { return }
        turns.append(StudyTurn(board: board, color: turn, point: nil))
        turn = 3 - turn; passes += 1
    }
    mutating func undo() {
        guard let old = turns.popLast() else { return }
        board = turns.last?.board ?? GoEngine.empty(size); turn = old.color
        passes = min(2, turns.reversed().prefix { $0.point == nil }.count)
        dead = []; confirmed = false
    }
    func position(at ply: Int) -> [Int] {
        guard ply > 0, !turns.isEmpty else { return GoEngine.empty(size) }
        return turns[min(ply, turns.count) - 1].board
    }
    mutating func retry(after ply: Int) {
        let count = min(max(ply, 0), turns.count)
        turns = Array(turns.prefix(count)); board = turns.last?.board ?? GoEngine.empty(size)
        turn = turns.last.map { 3 - $0.color } ?? 1
        passes = 0; dead = []; confirmed = false
    }
    mutating func resume() { passes = 0; dead = []; confirmed = false }
    mutating func toggleDead(_ point: Int) {
        guard paused, board.indices.contains(point), board[point] != 0 else { return }
        let group = GoEngine.group(board, at: point, size: size).stones
        if group.isSubset(of: dead) { dead.subtract(group) } else { dead.formUnion(group) }
        confirmed = false
    }
}

struct StudyRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var game: StudyPractice
}
