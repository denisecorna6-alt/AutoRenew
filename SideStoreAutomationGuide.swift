import SwiftUI

/// Explains how users can opt into SideStore's own public App Intent through
/// Shortcuts. AutoRenew does not invoke SideStore APIs or handle its credentials.
struct SideStoreAutomationGuide: View {
    var body: some View {
        Section("Atalhos do SideStore") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Use a ação oficial do SideStore", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                Text("O SideStore disponibiliza a ação “Refresh All Apps” para o app Atalhos no iOS 17 ou posterior. A renovação é executada pelo próprio SideStore; o AutoRenew não acessa a sessão Apple nem assina apps.")

                VStack(alignment: .leading, spacing: 8) {
                    instruction("1", "Instale e configure o SideStore pelo guia oficial. Confirme que o LocalDevVPN está conectado e que o iPhone tem internet.")
                    instruction("2", "Abra Atalhos, crie um atalho e adicione a ação do SideStore chamada “Refresh All Apps”.")
                    instruction("3", "Execute o atalho manualmente uma vez e confira o histórico do SideStore.")
                    instruction("4", "Em Atalhos > Automação, crie uma automação diária por horário e selecione esse atalho. Se disponível, escolha “Executar imediatamente”.")
                    instruction("5", "Escolha um horário em que o iPhone esteja ligado e com rede. Confira periodicamente o histórico do SideStore.")
                }

                Text("O iOS pode adiar automações. Sem internet, com LocalDevVPN desconectado ou se o sistema bloquear a execução, a renovação não acontece. A confirmação é o histórico do SideStore, não a mensagem inicial do Atalhos.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("A implementação pública do SideStore declara essa ação como ForegroundContinuableIntent e solicita continuação em primeiro plano se a operação ultrapassar cerca de 27 segundos. O Atalhos pode trazer o SideStore para a frente; não há garantia de execução totalmente silenciosa ou sem desbloquear o iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("O AutoRenew não chama a App Intent de outro aplicativo diretamente. Esta orientação usa o mecanismo público do SideStore por meio do Atalhos e exige configuração e consentimento no iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("Guia oficial de instalação do SideStore",
                     destination: URL(string: "https://docs.sidestore.io/docs/installation/install")!)
                    .font(.caption)
                Link("Ver a implementação pública do Refresh All Apps",
                     destination: URL(string: "https://github.com/SideStore/SideStore/blob/develop/AltStore/Intents/App%20Intents/RefreshAllAppsIntent.swift")!)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(.secondary.opacity(0.15), in: Circle())
            Text(text).font(.caption)
        }
    }
}
