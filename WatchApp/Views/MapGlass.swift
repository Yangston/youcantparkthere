import SwiftUI

private struct MapGlass<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 0.5))
        }
    }
}

extension View {
    func mapGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(MapGlass(shape: shape, interactive: interactive))
    }
}
