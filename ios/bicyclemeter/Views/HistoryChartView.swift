import SwiftUI
import CoreGraphics

struct HistoryChartView: View {
    let maxPoints: Double
    let range: (Double, Double)
    let points: [Double]

    var body: some View {
        let offsetY = 12.0
        let offsetX = 12.0

        GeometryReader { geometry in
            let pointWidth = (geometry.size.width - offsetX) / self.maxPoints
            let pointHeight = (geometry.size.height - offsetY) / (self.range.1 - self.range.0)

            let endX = geometry.size.width
            let endY = geometry.size.height
            let startX = endX - (Double(self.points.count) * pointWidth)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: startX, y: endY))

                    path.addLine(to: CGPoint(x: startX, y: endY - offsetY))

                    points.enumerated().forEach { (index, point) in
                        let normalizedPoint = point - self.range.0

                        path.addLine(to: CGPoint(
                            x: startX + Double(index + 1) * pointWidth,
                            y: endY - offsetY - normalizedPoint * pointHeight
                        ))
                    }

                    path.addLine(to: CGPoint(x: endX, y: endY))
                    path.addLine(to: CGPoint(x: startX, y: endY))
                }
                .fill(.linearGradient(
                    Gradient(colors: [
                        Color(red: 239.0 / 255, green: 80.0 / 255, blue: 80.0 / 255),
                        Color(red: 120.0 / 255, green: 200.0 / 255, blue: 80.0 / 255),
                    ]),
                    startPoint: UnitPoint(x: 0.5, y: 0.0),
                    endPoint: UnitPoint(x: 0.5, y: 1.0)
                ))
            }

            Text(range.0.formatted())
                .offset(CGSize(width: 0.0, height: geometry.size.height - offsetX))
                .font(.caption)
            Text(((range.1 + range.0) / 2.0).formatted())
                .offset(CGSize(width: 0.0, height: (geometry.size.height - offsetY) / 2.0))
                .font(.caption)
            Text(range.1.formatted())
                .offset(CGSize(width: 0.0, height: 0.0))
                .font(.caption)
        }
    }
}

struct HistoryChartView_Preview: PreviewProvider {
    static var previews: some View {
        HistoryChartView(
            maxPoints: 11.0,
            range: (0.0, 60.0),
            points: [42.0, 41.0, 40.0, 10.0, 45.0, 60.0, 30.0, 10.0, 0.0, 0.0, 25.0]
        )
        .padding(12.0)
    }
}
