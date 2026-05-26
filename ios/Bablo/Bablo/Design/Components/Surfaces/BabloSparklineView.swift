import SwiftUI

/// A premium, smooth sparkline chart component that displays a financial trend.
struct BabloSparklineView: View {
    let points: [Double]
    let color: Color
    
    init(points: [Double], color: Color) {
        self.points = points
        self.color = color
    }
    
    /// Converted initializer that takes a seed string (e.g. merchant name) to dynamically
    /// generate an aesthetically pleasing deterministic trend line if no real trend is provided.
    init(seed: String, color: Color) {
        self.points = Self.generateDeterministicPoints(from: seed)
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard points.count > 1 else { return }
                
                let width = geo.size.width
                let height = geo.size.height
                
                let minVal = points.min() ?? 0
                let maxVal = points.max() ?? 1
                let range = maxVal - minVal > 0 ? maxVal - minVal : 1
                
                let stepX = width / CGFloat(points.count - 1)
                
                // Dynamic scaling function
                let scaleY: (Double) -> CGFloat = { value in
                    height - CGFloat((value - minVal) / range) * height
                }
                
                // Draw bezier curves for smooth wavy lines
                var pointsList: [CGPoint] = []
                for index in points.indices {
                    let x = CGFloat(index) * stepX
                    let y = scaleY(points[index])
                    pointsList.append(CGPoint(x: x, y: y))
                }
                
                path.move(to: pointsList[0])
                
                for i in 0..<pointsList.count - 1 {
                    let p0 = pointsList[i]
                    let p1 = pointsList[i+1]
                    
                    // Bezier control points for smooth tension
                    let controlPoint1 = CGPoint(x: p0.x + stepX / 2, y: p0.y)
                    let controlPoint2 = CGPoint(x: p1.x - stepX / 2, y: p1.y)
                    
                    path.addCurve(to: p1, control1: controlPoint1, control2: controlPoint2)
                }
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    /// Generates a set of points (length 6-8) that are highly aesthetic, deterministic,
    /// and unique to the input string (seed).
    private static func generateDeterministicPoints(from seed: String) -> [Double] {
        let hash = abs(seed.hashValue)
        var generated: [Double] = []
        let pointCount = 6
        
        // Simple deterministic LCG-like calculation to ensure consistency
        var state = hash
        for _ in 0..<pointCount {
            state = (state &* 1103515245 &+ 12345) & 0x7fffffff
            let normalized = Double(state % 100) / 100.0
            generated.append(normalized)
        }
        
        // Apply a gentle moving average smoothing filter to make the wave look natural
        var smoothed: [Double] = []
        for i in 0..<generated.count {
            if i == 0 {
                smoothed.append((generated[0] + generated[1]) / 2.0)
            } else if i == generated.count - 1 {
                smoothed.append((generated[i-1] + generated[i]) / 2.0)
            } else {
                smoothed.append((generated[i-1] + generated[i] + generated[i+1]) / 3.0)
            }
        }
        
        return smoothed
    }
}

#Preview("Sparkline Sparkles") {
    VStack(spacing: 32) {
        BabloSparklineView(seed: "Concert Venue", color: .purple)
            .frame(width: 80, height: 24)
            .border(Color.gray.opacity(0.1))
        
        BabloSparklineView(seed: "Trader Joe's", color: .green)
            .frame(width: 80, height: 24)
            .border(Color.gray.opacity(0.1))
        
        BabloSparklineView(seed: "Blue Bottle Coffee", color: .red)
            .frame(width: 80, height: 24)
            .border(Color.gray.opacity(0.1))
    }
    .padding()
}
