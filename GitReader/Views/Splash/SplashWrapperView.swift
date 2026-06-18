import SwiftUI

struct SplashWrapperView<Content: View>: View {
    @State private var isActive = false
    let content: () -> Content
    
    var body: some View {
        ZStack {
            if isActive {
                content()
                    .transition(.opacity.animation(.easeOut(duration: 0.5)))
            } else {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        // 2.2s animation duration + 0.3s buffer = 2.5s total splash time
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation {
                                isActive = true
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    SplashWrapperView {
        Text("Main App Content")
    }
}
