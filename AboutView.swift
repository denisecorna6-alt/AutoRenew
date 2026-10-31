import SwiftUI

struct AboutView: View {
    private let pixKey = "7e67da92-268c-4a69-8a4c-eca7d01da74b"
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("AutoRenewLogo").resizable().scaledToFit().frame(maxWidth: 260).accessibilityLabel("Logo AutoRenew")
                    Text("Acompanhe · Gerencie · Renove").font(.headline)
                    Text("O AutoRenew é um projeto open source em desenvolvimento para acompanhar aplicativos e organizar o processo de renovação de assinaturas de sideloading.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    GroupBox("Apoie o desenvolvimento") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("A contribuição é voluntária e não é necessária para usar o projeto.")
                            Text("Pix — chave aleatória").font(.caption).foregroundStyle(.secondary)
                            Text(pixKey).font(.footnote.monospaced()).textSelection(.enabled)
                            ShareLink(item: pixKey) { Label("Compartilhar chave Pix", systemImage: "square.and.arrow.up") }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox("Parceiros e afiliados") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ainda não há parceiros ou links de afiliados cadastrados.")
                            Text("Links comerciais serão identificados como afiliados quando forem adicionados. O uso desses links é opcional.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Link("Código-fonte no GitHub", destination: URL(string: "https://github.com/denisecorna6-alt/AutoRenew")!).font(.headline)
                }.padding()
            }.navigationTitle("Sobre")
        }
    }
}