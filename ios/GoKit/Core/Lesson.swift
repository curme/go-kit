import Foundation

enum LessonKind: String { case move, select, quiz }

struct Lesson: Identifiable {
    let id: Int
    let title: String
    let tag: String
    let time: String
    let headline: String
    let intro: String
    let rule: String
    let task: String
    let size: Int
    let board: [Int]
    let kind: LessonKind
    let target: Set<Int>
    let options: [String]
    let answer: Int?
    let hint: String
    let success: String
    let takeaway: String
}

struct LearningProgress: Codable {
    var completed: Set<Int> = []
    var mistakes: Set<Int> = []
    var lastLesson = 0
    mutating func recordMistake(_ id: Int) { mistakes.insert(id) }
    mutating func complete(_ id: Int, independently: Bool) {
        completed.insert(id)
        if independently { mistakes.remove(id) }
        else { mistakes.insert(id) }
    }
}

struct LessonAttempt {
    let lesson: Lesson
    var board: [Int]
    var selected: Set<Int> = []
    var solved = false
    var usedHint = false
    var madeMistake = false
    var selectedAnswer: Int?
    var feedback = "慢慢来，想清楚再落子。下错也没关系。"
    var feedbackIsError = false
    init(_ lesson: Lesson) { self.lesson = lesson; board = lesson.board }
    var independently: Bool { !usedHint && !madeMistake }

    mutating func help() { usedHint = true; feedback = lesson.hint; feedbackIsError = false }
    mutating func reject(_ message: String) {
        madeMistake = true; feedback = message; feedbackIsError = true
    }
    mutating func finish() { solved = true; feedback = lesson.success; feedbackIsError = false }
    mutating func tap(_ point: Int) {
        guard !solved, lesson.kind != .quiz else { return }
        if lesson.kind == .select {
            guard lesson.target.contains(point) else {
                reject("气是与棋子沿线相邻的空点。斜角和已经有棋子的点不算。")
                return
            }
            if selected.contains(point) { selected.remove(point) } else { selected.insert(point) }
            feedback = "已找到 \(selected.count) / \(lesson.target.count) 口气。"; feedbackIsError = false
            if selected == lesson.target { finish() }
        } else {
            do {
                let move = try GoEngine.play(board, at: point, color: 1, size: lesson.size)
                guard lesson.target.contains(point) else {
                    reject("这手可以落子，但还没完成任务。再看看要救的是哪块棋、要封的是哪口气。")
                    return
                }
                board = move.board; selected = [point]; finish()
            } catch { reject(error.localizedDescription) }
        }
    }
    mutating func answer(_ index: Int) {
        guard !solved, lesson.kind == .quiz else { return }
        selectedAnswer = index
        if index == lesson.answer { finish() }
        else { reject("再读一遍本课规则，想想棋子的气和题目条件。你可以继续尝试。") }
    }
}
