import SwiftUI

/// Sound on/off, available in the top bar of every screen. One saved setting.
struct SoundButton: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        Button {
            store.soundOn.toggle()
            SoundService.shared.enabled = store.soundOn
            SoundService.shared.play(.tap)            // audible only when turning sound on
        } label: {
            RoundIconButton(systemName: store.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .environment(\.layoutDirection, .leftToRight)   // keep the speaker icon unmirrored
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(store.soundOn ? "الصوت يعمل، اضغط للكتم" : "الصوت مكتوم، اضغط للتشغيل")
        .accessibilityIdentifier("sound.button")
    }
}

/// Right side of every top bar (left in RTL): sound + coins.
struct TopBarActions: View {
    var body: some View {
        HStack(spacing: Theme.S.sm) {
            SoundButton()
            CoinButton()
        }
    }
}
