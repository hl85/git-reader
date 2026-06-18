import SwiftUI

struct LeftPageShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Scale coordinates from 100x100 design space to actual rect
        let scaleX = rect.width / 100
        let scaleY = rect.height / 100
        
        path.move(to: CGPoint(x: 50 * scaleX, y: 25 * scaleY))
        path.addCurve(
            to: CGPoint(x: 25 * scaleX, y: 50 * scaleY),
            control1: CGPoint(x: 35 * scaleX, y: 20 * scaleY),
            control2: CGPoint(x: 25 * scaleX, y: 30 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 50 * scaleX, y: 75 * scaleY),
            control1: CGPoint(x: 25 * scaleX, y: 70 * scaleY),
            control2: CGPoint(x: 35 * scaleX, y: 80 * scaleY)
        )
        return path
    }
}

struct RightPageShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 100
        let scaleY = rect.height / 100
        
        path.move(to: CGPoint(x: 50 * scaleX, y: 25 * scaleY))
        path.addCurve(
            to: CGPoint(x: 75 * scaleX, y: 50 * scaleY),
            control1: CGPoint(x: 65 * scaleX, y: 20 * scaleY),
            control2: CGPoint(x: 75 * scaleX, y: 30 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 50 * scaleX, y: 75 * scaleY),
            control1: CGPoint(x: 75 * scaleX, y: 70 * scaleY),
            control2: CGPoint(x: 65 * scaleX, y: 80 * scaleY)
        )
        return path
    }
}

struct SplashView: View {
    @State private var spineProgress: CGFloat = 0.0
    @State private var pagesProgress: CGFloat = 0.0
    @State private var nodesOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 12.0
    
    var body: some View {
        ZStack {
            ClaudeColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Vector Animation Container
                ZStack {
                    // Left Page
                    LeftPageShape()
                        .trim(from: 0, to: pagesProgress)
                        .stroke(ClaudeColors.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    // Right Page
                    RightPageShape()
                        .trim(from: 0, to: pagesProgress)
                        .stroke(ClaudeColors.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    // Spine (Git Branch Line)
                    GeometryReader { geo in
                        Path { path in
                            path.move(to: CGPoint(x: geo.size.width / 2, y: 10 * (geo.size.height / 100)))
                            path.addLine(to: CGPoint(x: geo.size.width / 2, y: 90 * (geo.size.height / 100)))
                        }
                        .trim(from: 0, to: spineProgress)
                        .stroke(ClaudeColors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    
                    // Top Node
                    Circle()
                        .fill(ClaudeColors.accent)
                        .frame(width: 8, height: 8)
                        .position(x: 60, y: 30) // 50% width, 25% height in 120x120 container
                        .opacity(nodesOpacity)
                    
                    // Bottom Node
                    Circle()
                        .fill(ClaudeColors.accent)
                        .frame(width: 8, height: 8)
                        .position(x: 60, y: 90) // 50% width, 75% height in 120x120 container
                        .opacity(nodesOpacity)
                }
                .frame(width: 120, height: 120)
                
                // Typography
                VStack(spacing: 8) {
                    Text("GitReader")
                        .font(.custom("Georgia", size: 30))
                        .fontWeight(.medium)
                        .foregroundColor(ClaudeColors.text)
                    
                    Text("YOUR OBSIDIAN VAULT")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .tracking(1.5)
                        .foregroundColor(ClaudeColors.textSecondary)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .onAppear {
            startAnimationPipeline()
        }
    }
    
    private func startAnimationPipeline() {
        // Phase 1: Draw Spine (0.0s - 0.6s)
        withAnimation(.cubicBezier(0.4, 0, 0.2, 1, duration: 0.6)) {
            spineProgress = 1.0
        }
        
        // Phase 2: Expand Pages (0.4s - 1.4s)
        withAnimation(.cubicBezier(0.4, 0, 0.2, 1, duration: 1.0).delay(0.4)) {
            pagesProgress = 1.0
        }
        
        // Phase 3: Fade in Nodes (1.0s - 1.4s)
        withAnimation(.easeIn(duration: 0.4).delay(1.0)) {
            nodesOpacity = 1.0
        }
        
        // Phase 4: Fade in Typography (1.2s - 2.0s)
        withAnimation(.cubicBezier(0.16, 1, 0.3, 1, duration: 0.8).delay(1.2)) {
            textOpacity = 1.0
            textOffset = 0.0
        }
    }
}

// Helper extension for custom cubic bezier curves in SwiftUI
extension Animation {
    static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, duration: Double = 0.35) -> Animation {
        return Animation.timingCurve(x1, y1, x2, y2, duration: duration)
    }
}

#Preview {
    SplashView()
}
