import SwiftUI

struct TestView: View {
    var body: some View {
        GlassEffectContainer {
            Text("Hello")
                .glassEffect()
        }
    }
}