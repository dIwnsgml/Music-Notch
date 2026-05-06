import SwiftUI

struct TestView: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color.red.frame(width: 10, height: 100)
            Color.blue.frame(width: 20, height: 20).offset(y: -10)
        }
        .rotationEffect(.degrees(45), anchor: .top)
        .position(x: 100, y: 150)
    }
}
