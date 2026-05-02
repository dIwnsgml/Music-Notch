import SwiftUI

struct TestView: View {
    var themeBackgroundType = "image"
    var themeGlassyWidgets = true
    
    var body: some View {
        Group {
            Text("Hello")
        }
        .background {
            if themeBackgroundType == "image" && themeGlassyWidgets {
                Color.clear.glassEffect(in: .rect(cornerRadius: 16))
            } else {
                Color.white.opacity(0.03)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
        }
    }
}