import SwiftUI

struct TagChipView: View {
    let topic: UserTopic
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                Text(topic.name)
                    .font(.label)

                if topic.isCustom {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(isSelected ? .snow : .dustyGrey)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.liquidLava : Color.slateGrey
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.liquidLava : Color.dustyGrey.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? .liquidLava.opacity(0.3) : .clear,
                radius: isSelected ? 6 : 0,
                y: 2
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
