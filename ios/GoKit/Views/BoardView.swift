import SwiftUI

struct BoardView: View {
    let board: [Int]
    let size: Int
    var selected: Set<Int> = []
    var liberties: Set<Int> = []
    var hints: Set<Int> = []
    var lastPoint: Int?
    var candidate: Int?
    var candidateColor = 1
    var territory: [Int] = []
    let onTap: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let step = geometry.size.width / CGFloat(size + 1)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Color(red: 0.92, green: 0.83, blue: 0.66), Color(red: 0.89, green: 0.77, blue: 0.56)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Palette.ink.opacity(0.12), radius: 8, y: 5)
                Path { path in
                    for line in 1...size {
                        let coordinate = CGFloat(line) * step
                        path.move(to: CGPoint(x: step, y: coordinate))
                        path.addLine(to: CGPoint(x: CGFloat(size) * step, y: coordinate))
                        path.move(to: CGPoint(x: coordinate, y: step))
                        path.addLine(to: CGPoint(x: coordinate, y: CGFloat(size) * step))
                    }
                }.stroke(Color.brown.opacity(0.55), lineWidth: 0.8).accessibilityHidden(true)

                ForEach(0..<size, id: \.self) { i in
                    Text(String(Array("ABCDEFGHJKLMNOPQRST")[i])).font(.system(size: size == 19 ? 7 : 10, design: .serif))
                        .position(x: CGFloat(i + 1) * step, y: step * 0.35)
                    Text("\(size - i)").font(.system(size: 10, design: .serif))
                        .position(x: step * 0.35, y: CGFloat(i + 1) * step)
                }.foregroundStyle(Color.brown).accessibilityHidden(true)

                ForEach(stars, id: \.self) { point in
                    Circle().fill(Color.brown.opacity(0.65)).frame(width: 4, height: 4)
                        .position(x: CGFloat(point % size + 1) * step, y: CGFloat(point / size + 1) * step)
                        .accessibilityHidden(true)
                }
                ForEach(board.indices, id: \.self) { point in
                    Button { onTap(point) } label: {
                        ZStack {
                            Color.clear
                            if board[point] != 0 {
                                stone(board[point]).padding(step * 0.08)
                                if selected.contains(point) {
                                    Circle().stroke(Color.orange, lineWidth: 3).padding(step * 0.05)
                                }
                                if point == lastPoint {
                                    Circle().stroke(board[point] == 1 ? Color.white.opacity(0.8) : Palette.green, lineWidth: 1.5)
                                        .frame(width: 7, height: 7)
                                }
                            } else if candidate == point {
                                stone(candidateColor).padding(step * 0.08).opacity(0.45)
                                Image(systemName: "plus").font(.caption).foregroundStyle(candidateColor == 1 ? Color.white : Palette.green)
                            } else if selected.contains(point) {
                                Circle().fill(Palette.green.opacity(0.2)).padding(step * 0.12)
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(Palette.green)
                            } else if hints.contains(point) || liberties.contains(point) {
                                Circle().stroke(Palette.green, style: StrokeStyle(lineWidth: 2, dash: hints.contains(point) ? [3, 3] : []))
                                    .padding(step * 0.3)
                            } else if territory.indices.contains(point), territory[point] != 0 {
                                RoundedRectangle(cornerRadius: 1).fill(territory[point] == 1 ? Palette.ink : Color.white)
                                    .frame(width: 7, height: 7)
                            }
                        }.frame(width: step, height: step).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: CGFloat(point % size + 1) * step, y: CGFloat(point / size + 1) * step)
                    .accessibilityLabel("\(GoEngine.coordinate(point, size: size))，\(board[point] == 1 ? "黑子" : board[point] == 2 ? "白子" : "空点")")
                    .accessibilityValue(selected.contains(point) ? "重点棋子或已选择" : liberties.contains(point) ? "气" : hints.contains(point) ? "提示点" : "")
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(size) 路棋盘")
    }

    private var stars: [Int] {
        if size == 19 { return [60, 66, 72, 174, 180, 186, 288, 294, 300] }
        if size == 13 { return [42, 48, 84, 120, 126] }
        return size == 9 ? [20, 24, 40, 56, 60] : [12]
    }
    private func stone(_ color: Int) -> some View {
        Circle().fill(RadialGradient(colors: color == 1 ? [Color(white: 0.35), Color(white: 0.08)] : [.white, Color(white: 0.9)], center: .topLeading, startRadius: 0, endRadius: 45))
            .shadow(color: .black.opacity(0.23), radius: 2, x: 1, y: 3)
    }
}
