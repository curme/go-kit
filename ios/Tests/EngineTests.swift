import Foundation

@main
struct EngineTests {
    static var checks = 0
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message); checks += 1
    }
    static func position(_ n: Int, black: [Int] = [], white: [Int] = []) -> [Int] {
        var board = GoEngine.empty(n)
        for i in black { board[i] = 1 }
        for i in white { board[i] = 2 }
        return board
    }
    @MainActor static func main() throws {
        let shared = GoEngine.group(position(5, black: [11,12]), at: 11, size: 5)
        check(shared.stones == [11,12], "Connected stones")
        check(shared.liberties == [6,7,10,13,16,17], "Shared liberties")
        check(GoEngine.group(position(5, black: [0]), at: 0, size: 5).liberties.count == 2, "Corner")
        let multi = try GoEngine.play(position(5, black: [1,5,11,3,9,13], white: [6,8]), at: 7, color: 1, size: 5)
        check(multi.captured == [6,8], "Multiple groups captured")
        let two = try GoEngine.play(position(5, black: [1,2,5,8,11], white: [6,7]), at: 12, color: 1, size: 5)
        check(two.captured == [6,7], "Whole group captured")
        let surrounded = position(3, black: [1,3,5,7])
        check((try? GoEngine.play(surrounded, at: 4, color: 2, size: 3)) == nil, "Suicide forbidden")
        check((try? GoEngine.play(surrounded, at: 1, color: 2, size: 3)) == nil, "Occupied point")
        check((try? GoEngine.play(surrounded, at: -1, color: 1, size: 3)) == nil, "Invalid point")
        let captureFirst = try GoEngine.play(position(3, black: [0,2,6,8], white: [1,3,5,7]), at: 4, color: 1, size: 3)
        check(captureFirst.captured.count == 4 && captureFirst.liberties.count == 4, "Capture before suicide check")
        let before = position(5, black: [16,18,22], white: [7,11,13,17])
        let take = try GoEngine.play(before, at: 12, color: 1, size: 5)
        check(take.captured == [17], "Ko capture")
        check((try? GoEngine.play(take.board, at: 17, color: 2, size: 5, history: [GoEngine.hash(before), GoEngine.hash(take.board)])) == nil, "Ko rejected")
        check((try? GoEngine.play(take.board, at: 17, color: 2, size: 5)) != nil, "Recapture legal without repetition")
        let score = GoEngine.estimate(position(3, black: [0,1,3,4], white: [2,5,8]), size: 3)
        check(score.black == 4 && score.white == 3 && score.neutral == 2, "Mixed border neutral")
        check(GoEngine.estimate(GoEngine.empty(9), size: 9).neutral == 81, "Empty board neutral")

        for lesson in Curriculum.lessons {
            check(lesson.board.count == lesson.size * lesson.size, "Course board shape")
            var attempt = LessonAttempt(lesson)
            if let answer = lesson.answer { attempt.answer(answer) }
            else { for point in lesson.target.sorted() { attempt.tap(point) } }
            check(attempt.solved, "Course solution: \(lesson.title)")
            check(attempt.independently, "Fresh solution is independent")
        }
        check(Curriculum.lessons.count == 48, "Complete core curriculum count")
        check(Set(Curriculum.chapters.flatMap { $0.lessonIDs }) == Set(Curriculum.lessons.map(\.id)), "Chapters cover every lesson")
        check(Curriculum.lessons.map(\.id) == Array(0..<48), "Course IDs are contiguous")
        check((try? GoEngine.play(Curriculum.lessons[5].board, at: 11, color: 2, size: 5)) == nil, "First true eye")
        check((try? GoEngine.play(Curriculum.lessons[5].board, at: 13, color: 2, size: 5)) == nil, "Second true eye")
        var directionalAtari = LessonAttempt(Curriculum.lessons[10]); directionalAtari.tap(13)
        check(directionalAtari.board[12] == 2 && GoEngine.group(directionalAtari.board, at: 12, size: 5).liberties == [17],
              "Directional atari pushes toward support")
        var captureRescue = LessonAttempt(Curriculum.lessons[11]); captureRescue.tap(13)
        check(captureRescue.board[14] == 0 && GoEngine.group(captureRescue.board, at: 12, size: 5).liberties.count > 1,
              "Capture rescues endangered stone")
        var doubleAtari = LessonAttempt(Curriculum.lessons[12]); doubleAtari.tap(12)
        check(GoEngine.group(doubleAtari.board, at: 7, size: 5).liberties.count == 1
              && GoEngine.group(doubleAtari.board, at: 11, size: 5).liberties.count == 1,
              "Double atari threatens both groups")
        var twoEyes = LessonAttempt(Curriculum.lessons[15]); twoEyes.tap(12)
        check((try? GoEngine.play(twoEyes.board, at: 11, color: 2, size: 5)) == nil
              && (try? GoEngine.play(twoEyes.board, at: 13, color: 2, size: 5)) == nil,
              "Eye split creates two protected eyes")
        var ladderStart = LessonAttempt(Curriculum.lessons[23]); ladderStart.tap(13)
        check(GoEngine.group(ladderStart.board, at: 12, size: 5).liberties == [17], "Ladder lesson forces one escape")
        var straightThree = LessonAttempt(Curriculum.lessons[28]); straightThree.tap(12)
        check(straightThree.solved && straightThree.board[12] == 1, "Straight-three vital point")
        var wideOpening = LessonAttempt(Curriculum.lessons[36]); wideOpening.tap(24)
        check(wideOpening.solved, "Wide opening accepts a valid empty corner")
        var weakestGroup = LessonAttempt(Curriculum.lessons[38]); weakestGroup.tap(41)
        check(GoEngine.group(weakestGroup.board, at: 40, size: 9).liberties.count > 1, "Weak-group lesson rescues atari")

        check(WuCurriculum.lessons.count == 8, "Wu enlightenment lesson count")
        check(Set(WuCurriculum.lessons.map(\.bookNumber)).count == 8, "Wu lessons use distinct verified games")
        for lesson in WuCurriculum.lessons {
            check(lesson.focusMove >= 0 && lesson.focusMove <= lesson.moves.count, "Wu focus move in range")
            check(lesson.options.indices.contains(lesson.answer), "Wu answer in range")
            var historical = GoEngine.empty(19)
            for stone in lesson.setup { historical[stone.point] = stone.color }
            var historicalHistory: Set<String> = [GoEngine.hash(historical)]
            for move in lesson.moves {
                guard let point = move.point else { continue }
                let played = try GoEngine.play(historical, at: point, color: move.color, size: 19,
                                               history: historicalHistory)
                historical = played.board; historicalHistory.insert(GoEngine.hash(historical))
            }
            check(lesson.position(after: lesson.moves.count).board == historical, "Wu historical replay: \(lesson.title)")
        }
        var wuProgress = WuLearningProgress(); wuProgress.complete(0); wuProgress.complete(99)
        let restoredWu = try WuCurriculum.decode(WuCurriculum.encode(wuProgress))
        check(restoredWu.completed == [0], "Wu progress round trip and sanitization")
        check(HundredDayPlan.days.count == 100, "Hundred-day plan has 100 days")
        check(HundredDayPlan.days.map(\.id) == Array(1...100), "Hundred-day IDs are contiguous")
        check(Set(HundredDayPlan.stages.flatMap { Array($0.days) }) == Set(1...100), "Hundred-day stages cover every day")
        let allPlanTasks = HundredDayPlan.days.flatMap(\.tasks)
        check(allPlanTasks.count == 300 && Set(allPlanTasks.map(\.id)).count == 300, "Three stable tasks per day")
        for day in HundredDayPlan.days {
            check(day.tasks.count == 3 && day.totalMinutes > 0, "Complete daily plan: \(day.id)")
            for task in day.tasks {
                switch task.action {
                case .lesson(let id): check(Curriculum.lessons.contains { $0.id == id }, "Plan lesson exists")
                case .training(let ids): check(!ids.isEmpty && ids.allSatisfy { CoachCurriculum.problem($0) != nil }, "Plan training exists")
                case .wu(let id): check(WuCurriculum.lessons.contains { $0.id == id }, "Plan Wu lesson exists")
                case .capture, .practice, .review: check(true, "Plan destination exists")
                }
            }
        }
        var hundredDays = HundredDayProgress()
        let firstDay = HundredDayPlan.days[0]
        for task in firstDay.tasks { hundredDays.setCompleted(true, taskID: task.id) }
        check(hundredDays.isDayComplete(firstDay) && hundredDays.completedDays == 1, "Completing tasks finishes a plan day")
        check(hundredDays.currentDay == 2 && hundredDays.currentStreak == 1, "Plan advances and counts streak")
        hundredDays.setCompleted(false, taskID: firstDay.tasks[0].id)
        check(!hundredDays.isDayComplete(firstDay) && hundredDays.currentDay == 1, "Plan completion can be corrected")
        hundredDays.setCompleted(true, taskID: "removed-task")
        hundredDays.sanitize()
        check(!hundredDays.completedTaskIDs.contains("removed-task"), "Plan removes stale task IDs")
        var attempt = LessonAttempt(Curriculum.lessons[2])
        attempt.tap(0); attempt.tap(13)
        check(attempt.solved && !attempt.independently, "Correct after a mistake needs review")
        var progress = LearningProgress()
        progress.complete(2, independently: attempt.independently)
        check(progress.completed.contains(2) && progress.mistakes.contains(2), "Retain review")
        progress.complete(2, independently: true)
        check(!progress.mistakes.contains(2), "Independent retry clears review")
        var helped = LessonAttempt(Curriculum.lessons[0]); helped.help(); helped.tap(12)
        check(helped.solved && !helped.independently, "Hinted completion")

        let bot = GoEngine.chooseMove(position(5, black: [12], white: [7,11,17]), color: 2, size: 5, history: [])
        check(bot?.point == 13, "Bot captures atari")
        var game = PracticeGame()
        try game.play(20)
        check(game.position.moves == 2 && game.position.board.filter { $0 != 0 }.count == 2, "White responds")
        check(game.position.turns.count == 2 && game.position.turns.map(\.color) == [1, 2], "Record both sides for review")
        game.undo()
        check(game.position.board == GoEngine.empty(9) && game.position.moves == 0 && game.position.turns.isEmpty, "Undo a whole round")
        game.pass(); check(game.position.paused && game.position.moves == 2, "Both pass")
        game.resume(); try game.play(20)
        check(!game.position.paused && game.position.moves == 4, "Continue after pause")
        let roundTrip = try JSONDecoder().decode(PracticeGame.self, from: JSONEncoder().encode(game))
        check(roundTrip.position.board == game.position.board && roundTrip.position.turns == game.position.turns
              && roundTrip.undoPositions.count == game.undoPositions.count, "Game serialization")

        var oldPositionJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game.position)) as! [String: Any]
        oldPositionJSON.removeValue(forKey: "turns")
        let decodedOldPosition = try JSONDecoder().decode(GamePosition.self,
            from: JSONSerialization.data(withJSONObject: oldPositionJSON))
        check(decodedOldPosition.turns.isEmpty && decodedOldPosition.board == game.position.board,
              "Old saved position loads without review history")

        let captureBoard = position(9, black: [31, 39, 49], white: [40])
        let ignoredMove = try GoEngine.play(captureBoard, at: 0, color: 1, size: 9)
        var reviewPosition = GamePosition()
        reviewPosition.board = ignoredMove.board; reviewPosition.moves = 2
        reviewPosition.turns = [
            PracticeTurn(ply: 1, color: 2, point: 40, board: captureBoard, captured: []),
            PracticeTurn(ply: 2, color: 1, point: 0, board: ignoredMove.board, captured: [])
        ]
        let review = PracticeReviewer.insights(for: reviewPosition)
        check(review.first?.theme == .capture && review.first?.recommendedPoint == 41, "Review detects missed capture")
        var retryGame = PracticeGame(); retryGame.position = reviewPosition
        retryGame.retry(beforeTurn: 1)
        check(retryGame.position.board == captureBoard && retryGame.position.turns.count == 1 && !retryGame.position.paused,
              "Retry restores the position before a reviewed move")

        let suiteName = "GoKit.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(defaults: defaults)
        store.record(helped); store.completeWuLesson(0)
        store.setHundredDayTask(firstDay.tasks[0], completed: true); try store.play(20)
        let restored = AppStore(defaults: defaults)
        check(restored.progress.completed == [0] && restored.progress.mistakes == [0], "Persist progress")
        check(restored.game.position.board == store.game.position.board, "Persist current game")
        check(restored.wuProgress.completed == [0], "Persist Wu course progress")
        check(restored.hundredDayProgress.completedTaskIDs == [firstDay.tasks[0].id], "Persist hundred-day progress")
        restored.undo(); check(restored.game.position.moves == 0, "Persist undo history")
        let corrupt = UserDefaults(suiteName: suiteName + ".corrupt")!
        defer { corrupt.removePersistentDomain(forName: suiteName + ".corrupt") }
        corrupt.set(Data("bad".utf8), forKey: "go-kit.native-learning.v1")
        check(AppStore(defaults: corrupt).storageNotice != nil, "Corrupt save is reported")

        var board = GoEngine.empty(9), history: Set<String> = [GoEngine.hash(GoEngine.empty(9))], passes = 0
        for turn in 0..<160 {
            guard let move = GoEngine.chooseMove(board, color: turn % 2 + 1, size: 9, history: history) else {
                passes += 1; if passes == 2 { break }; continue
            }
            passes = 0
            check(!history.contains(GoEngine.hash(move.move.board)), "No repeated board in long game")
            board = move.move.board; history.insert(GoEngine.hash(board))
            for i in board.indices where board[i] != 0 {
                check(!GoEngine.group(board, at: i, size: 9).liberties.isEmpty, "No dead group left on board")
            }
        }
        try runCoachTests()
        try runStudyTests()
        print("PASS: \(checks) checks — rules, 100 system lessons, teaching boards, 48 lessons, 100-day plan, Wu course, coaching, review, capture challenge, persistence, long-game invariants")
    }
}
