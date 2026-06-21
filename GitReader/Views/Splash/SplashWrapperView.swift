import SwiftUI

struct SplashWrapperView<Content: View>: View {
    @State private var isActive = false
    let content: () -> Content
    
    var body: some View {
        if isActive {
            content()
        } else {
            SplashView()
                .onAppear {
                    // 2.2s animation duration + 0.3s buffer = 2.5s total splash time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            isActive = true
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
