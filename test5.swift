import SwiftUI

struct TestView: View {
    var armLength: CGFloat = 80
    var body: some View {
        ZStack(alignment: .center) {
            Capsule()
                .fill(Color(white: 0.8))
                .frame(width: 4, height: armLength)
                .offset(y: armLength / 2)
            
            Rectangle()
                .frame(width: 10, height: 20)
                .rotationEffect(.degrees(20), anchor: .top)
                .offset(y: armLength)
        }
        .frame(width: 0, height: 0)
    }
}
