import Foundation

struct StudyExercise: Identifiable {
    let id: String
    let prompt: String
    let explanation: String
    var options: [String] = []
    var answer: Int = 0
    var size: Int = 5
    var board: [Int] = []
    // A branch alternates black (student) and white (authored response).
    // Several branches may share a prefix. Student can complete any accepted branch.
    var branches: [[Int]] = []
    var focus: Set<Int> = []
    var isBoardTask: Bool { !branches.isEmpty }
}

struct StudyLesson: Identifiable {
    let id: Int
    let title: String
    let objective: String
    let explanation: String
    let example: String
    let application: String
    let exercises: [StudyExercise]
    var demonstration: StudyExercise?
    var wuID: Int?
    var chapter: Int { (id - 1) / 10 }
    var assessment: Bool { id % 10 == 0 }
}

struct StudyAttempt {
    let exercise: StudyExercise
    private(set) var board: [Int]
    private(set) var played: [Int] = []
    private(set) var solved = false
    private(set) var mistake = false
    private(set) var hinted = false
    private(set) var feedback = "先自己判断，再提交答案。"
    private(set) var selectedAnswer: Int?
    private(set) var lastPoint: Int?
    var independent: Bool { solved && !mistake && !hinted }
    var candidates: Set<Int> {
        Set(exercise.branches.filter { $0.starts(with: played) && $0.count > played.count }
            .map { $0[played.count] })
    }

    init(_ exercise: StudyExercise, prior: StudyResult? = nil) {
        self.exercise = exercise
        board = exercise.board
        // An interrupted attempt starts its diagram again, keeping assistance/error evidence.
        if let prior, !prior.solved { mistake = prior.mistake; hinted = prior.hinted }
    }

    mutating func help() {
        guard !solved else { return }
        hinted = true
        feedback = exercise.isBoardTask ? "圈出的点是本步参考着。看过提示后，本题会留在复习列表。" : exercise.explanation
    }

    mutating func answer(_ index: Int) {
        guard !solved, !exercise.isBoardTask, exercise.options.indices.contains(index) else { return }
        selectedAnswer = index
        if index == exercise.answer { solved = true; feedback = exercise.explanation }
        else { mistake = true; feedback = "再比较题目条件。" + exercise.explanation }
    }

    mutating func play(_ point: Int) {
        guard !solved, exercise.isBoardTask else { return }
        do {
            // Replay the accepted prefix to enforce all earlier repetitions.
            var history: Set<String> = [GoEngine.hash(exercise.board)]
            var historical = exercise.board
            for (i, p) in played.enumerated() {
                historical = try GoEngine.play(historical, at: p, color: i % 2 + 1,
                    size: exercise.size, history: history).board
                history.insert(GoEngine.hash(historical))
            }
            let next = try GoEngine.play(board, at: point, color: 1, size: exercise.size, history: history)
            guard candidates.contains(point) else {
                mistake = true
                feedback = "这手合法，但没有完成本题指定的演练步骤。先检查目标棋块的气和连接，再试一次。"
                return
            }
            played.append(point); board = next.board; lastPoint = point
            history.insert(GoEngine.hash(board))
            if exercise.branches.contains(played) { solved = true; feedback = exercise.explanation; return }
            guard let branch = exercise.branches.first(where: { $0.starts(with: played) }), branch.count > played.count else { return }
            let reply = branch[played.count]
            board = try GoEngine.play(board, at: reply, color: 2, size: exercise.size, history: history).board
            played.append(reply); lastPoint = reply
            if exercise.branches.contains(played) { solved = true; feedback = exercise.explanation }
            else { feedback = "白棋应在 \(GoEngine.coordinate(reply, size: exercise.size))。现在请你继续，读完这条变化。" }
        } catch { mistake = true; feedback = error.localizedDescription }
    }
}

struct StudyResult: Codable {
    var solved = false
    var mistake = false
    var hinted = false
    var independent: Bool { solved && !mistake && !hinted }
}

struct StudyProgress: Codable {
    var version = 1
    var results: [String: StudyResult] = [:]
    var learned: Set<Int> = []
    var applications: Set<Int> = []
    var review: Set<Int> = []
    var activeDates: Set<String> = []
    var lastLesson = 1

    mutating func record(_ attempt: StudyAttempt, lesson: StudyLesson, now: Date = Date()) {
        guard lesson.exercises.contains(where: { $0.id == attempt.exercise.id }) else { return }
        if results[attempt.exercise.id]?.solved == true && !attempt.solved { return }
        var result = results[attempt.exercise.id] ?? StudyResult()
        result.solved = result.solved || attempt.solved
        result.hinted = result.hinted || attempt.hinted
        result.mistake = result.mistake || attempt.mistake
        results[attempt.exercise.id] = result
        if result.mistake || result.hinted { review.insert(lesson.id) }
        if lesson.exercises.allSatisfy({ results[$0.id]?.independent == true }) { review.remove(lesson.id) }
        lastLesson = lesson.id
        if attempt.solved {
            let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian)
            format.locale = Locale(identifier: "en_US_POSIX"); format.dateFormat = "yyyy-MM-dd"
            activeDates.insert(format.string(from: now))
        }
        if lesson.exercises.allSatisfy({ results[$0.id]?.solved == true }) { learned.insert(lesson.id) }
    }

    func independentCount(_ lesson: StudyLesson) -> Int {
        lesson.exercises.filter { results[$0.id]?.independent == true }.count
    }
    func needsReview(_ lesson: StudyLesson) -> Bool {
        review.contains(lesson.id) || lesson.exercises.contains { results[$0.id]?.mistake == true || results[$0.id]?.hinted == true }
    }
    func passed(_ lesson: StudyLesson) -> Bool {
        learned.contains(lesson.id) && independentCount(lesson) >= Int(ceil(Double(lesson.exercises.count) * 0.8))
            && lesson.exercises.last.map { results[$0.id]?.independent == true } == true
    }
    mutating func restart(_ lesson: StudyLesson) {
        if needsReview(lesson) { review.insert(lesson.id) }
        for exercise in lesson.exercises { results.removeValue(forKey: exercise.id) }
        // Keep the historical fact that the lesson was studied, but require a fresh pass.
    }
    mutating func sanitize() {
        let valid = Set(StudyCatalog.lessons.flatMap(\.exercises).map(\.id))
        results = results.filter { valid.contains($0.key) }
        let ids = Set(StudyCatalog.lessons.map(\.id))
        learned.formIntersection(ids); applications.formIntersection(ids); review.formIntersection(ids)
        if !ids.contains(lastLesson) { lastLesson = 1 }
    }
}

enum StudyCatalog {
    static let storageKey = "go-kit.study-course.v2"
    static let chapterTitles = ["开始和结束一盘棋", "连接、棋形与方向", "读完吃子手筋", "做活与破眼", "对杀与读棋",
                                "全盘方向", "理解定式的目的", "攻击与取舍", "收官与形势", "独立实战与复盘"]
    static let lessons: [StudyLesson] = StudyContent.makeLessons()
}
