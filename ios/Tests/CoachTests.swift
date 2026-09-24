import Foundation

extension EngineTests {
    @MainActor static func runCoachTests() throws {
        let expectedCounts = [3, 2, 5]
        let expectedMoves: [Set<Int>] = [[13], [12], [5], [13], [5], [12], [1]]
        check(CoachCurriculum.problems.count == 10, "Ten original problems")
        check(Set(CoachCurriculum.problems.map(\.id)).count == 10, "Stable unique problem IDs")
        check(CoachCurriculum.guidedIDs.compactMap(CoachCurriculum.problem).count == 3, "Three guided steps exist")
        for (i, problem) in CoachCurriculum.problems.enumerated() {
            check(problem.board.count == 25, "Training board dimensions")
            for p in problem.board.indices where problem.board[p] != 0 {
                check(!GoEngine.group(problem.board, at: p, size: 5).liberties.isEmpty, "Training starts with living groups")
            }
            var attempt = TrainingAttempt(problem)
            if i < 3 {
                check(problem.group.liberties.count == expectedCounts[i], "Independently specified liberty answer")
                check(problem.options.contains(expectedCounts[i]), "Count answer selectable")
                attempt.answer(expectedCounts[i])
                var wrong = TrainingAttempt(problem)
                wrong.answer(problem.options.first { $0 != expectedCounts[i] }!)
                check(wrong.needsRetry && wrong.madeMistake, "Wrong count requires retry")
                wrong.retry(); wrong.answer(expectedCounts[i])
                check(wrong.solved && !wrong.independent, "Wrong count cannot become independent in same attempt")
            } else {
                check(problem.solutions == expectedMoves[i - 3], "All accepted moves match authored solution: \(problem.id)")
                attempt.play(expectedMoves[i - 3].first!)
            }
            check(attempt.solved && attempt.independent, "Fresh answer is independent: \(problem.id)")
            var hinted = TrainingAttempt(problem); hinted.help()
            if i < 3 { hinted.answer(expectedCounts[i]) } else { hinted.play(expectedMoves[i - 3].first!) }
            check(hinted.solved && !hinted.independent, "Hints prevent mastery: \(problem.id)")
            var progress = TrainingProgress()
            progress.record(hinted)
            check(progress.review.contains(problem.id) && !progress.mastered.contains(problem.id), "Hinted solution retained")
            progress.record(attempt)
            check(progress.mastered.contains(problem.id) && !progress.review.contains(problem.id), "Fresh independent solution clears review")
        }
        var rescue = TrainingAttempt(CoachCurriculum.problems[6])
        rescue.play(0)
        check(rescue.needsRetry && rescue.demonstrationPoint == 13, "Missed rescue has concrete response")
        check(rescue.marked == [12] && rescue.liberties == [13], "Threat highlights exact group and liberty")
        rescue.demonstrate()
        check(rescue.board[12] == 0 && rescue.board[13] == 2, "Demonstration captures the threatened stone")
        rescue.retry()
        check(rescue.board == rescue.problem.board && rescue.madeMistake && !rescue.demonstrated, "Retry restores board but preserves error")
        rescue.play(13)
        check(rescue.solved && !rescue.independent, "Rescue after explanation needs later review")
        var invalid = TrainingAttempt(CoachCurriculum.problems[3])
        invalid.play(7)
        check(invalid.board == invalid.problem.board && invalid.needsRetry, "Illegal lesson move does not change board")
        var curriculumProgress = TrainingProgress()
        curriculumProgress.mastered = ["count-center"]
        curriculumProgress.review = ["rescue-one"]
        check(curriculumProgress.queue.first?.id == "rescue-one" && curriculumProgress.queue.last?.id == "count-center", "Adaptive queue prioritizes review then unseen")
        curriculumProgress.mastered.insert("removed"); curriculumProgress.review.insert("count-center")
        curriculumProgress.sanitize()
        check(!curriculumProgress.mastered.contains("removed") && !curriculumProgress.mastered.contains("count-center"), "Sanitize stale and overlapping IDs")

        var won = try captureFixture(black: [7, 11, 17], white: [12])
        let winningStart = won.position.board
        try won.play(13)
        check(won.position.outcome == .won && won.position.moves == 1 && won.position.board[12] == 0, "First capture wins immediately, no white reply")
        let terminalBoard = won.position.board
        try won.play(0); won.pass()
        check(won.position.board == terminalBoard && won.position.moves == 1, "Finished game cannot be played or passed")
        won.undo()
        check(won.position.outcome == .playing && won.position.board == winningStart, "Undo winning turn")
        var lost = try captureFixture(black: [12], white: [7, 11, 17])
        try lost.play(0)
        check(lost.position.outcome == .lost && lost.position.moves == 2 && lost.position.board[12] == 0, "White wins by immediate capture")
        lost.undo()
        check(lost.position.board[12] == 1 && lost.position.moves == 0, "Undo loss restores threatened stone")
        var captureWinsDespiteAtari = try captureFixture(black: [0, 6, 10], white: [1])
        try captureWinsDespiteAtari.play(24)
        check(captureWinsDespiteAtari.position.outcome == .lost && captureWinsDespiteAtari.position.board[5] == 2,
              "In capture Go immediate capture beats rescuing a group, even with only one liberty afterward")
        var draw = try captureFixture(black: [], white: [], moves: 79)
        try draw.play(12)
        check(draw.position.outcome == .draw && draw.position.moves == 80, "80-ply limit ends before white reply")
        var passes = try captureFixture(black: [], white: [], passes: 1)
        passes.pass()
        check(passes.position.outcome == .draw && passes.position.consecutivePasses == 2, "Two consecutive passes draw")
        var occupied = try captureFixture(black: [12], white: [])
        do { try occupied.play(12); check(false, "Occupied move must throw") } catch GoError.occupied { }
        check(occupied.undoPositions.isEmpty && occupied.position.moves == 0, "Invalid move creates no undo state")
        let encoded = try JSONEncoder().encode(lost)
        let decoded = try JSONDecoder().decode(CaptureGame.self, from: encoded)
        check(decoded.isValid && decoded.position.board == lost.position.board, "Challenge round trip")
        var malformed = CapturePosition(); malformed.board = [1]
        check(!malformed.isValid, "Malformed board rejected")
        malformed = CapturePosition(); malformed.highlighted = [99]
        check(!malformed.isValid, "Invalid highlight rejected")

        for seed in 0..<8 {
            var game = CaptureGame()
            for turn in 0..<45 where game.position.outcome == .playing {
                let legal = game.position.board.indices.filter {
                    (try? GoEngine.play(game.position.board, at: $0, color: 1, size: 5, history: game.position.history)) != nil
                }
                if legal.isEmpty { game.pass() }
                else { try game.play(legal[(seed * 7 + turn * 3) % legal.count]) }
                check(game.isValid, "Challenge state invariant")
                for p in game.position.board.indices where game.position.board[p] != 0 {
                    check(!GoEngine.group(game.position.board, at: p, size: 5).liberties.isEmpty, "Challenge removes dead groups")
                }
            }
            check(game.position.outcome != .playing, "Challenge always terminates")
        }
        let suite = "GoKit.CoachTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.recordTraining(rescue); store.completeGuidedTraining(); try store.playCapture(12)
        let restored = AppStore(defaults: defaults)
        check(restored.training.guidedCompleted && restored.training.review == ["rescue-one"], "Persist guided lesson and review")
        check(restored.captureGame.position.board == store.captureGame.position.board, "Persist challenge board")
        restored.undoCapture()
        check(restored.captureGame.position.moves == 0, "Persist challenge undo")
        defaults.removeObject(forKey: "go-kit.native-coach.v1")
        let legacy = AppStore(defaults: defaults)
        check(legacy.storageNotice == nil && legacy.training.mastered.isEmpty, "Existing users without coach save load normally")
        defaults.set(Data("bad".utf8), forKey: "go-kit.native-coach.v1")
        let corrupt = AppStore(defaults: defaults)
        check(corrupt.storageNotice != nil && corrupt.captureGame.isValid, "Corrupt coach save resets safely")
    }
    static func captureFixture(black: [Int], white: [Int], moves: Int = 0, passes: Int = 0) throws -> CaptureGame {
        struct Fixture: Encodable { var position: CapturePosition; var undoPositions: [CapturePosition] = [] }
        var p = CapturePosition()
        p.board = position(5, black: black, white: white); p.history = [GoEngine.hash(p.board)]
        p.moves = moves; p.consecutivePasses = passes
        return try JSONDecoder().decode(CaptureGame.self, from: JSONEncoder().encode(Fixture(position: p)))
    }
}
