import SwiftUI

/// Documents the supported cross-app handoff: the user configures SideStore's
/// own App Intent in Shortcuts. AutoRenew does not invoke private APIs or claim
/// that its own background task can sign apps owned by another app.
struct SideStoreAutomationGuide: View {
    var body: some View {
        Section("Renovação automática pelo SideStore") {
            VStack(alignment: .leading, spacing: 10) {
                Label("Use a ação oficial do SideStore", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                Text("O SideStore disponibiliza a ação “Refresh All Apps” para o app Atalhos (iOS 17 ou posterior). Ela executa o mecanismo de renovação do próprio SideStore; o AutoRenew não acessa a sessão Apple nem tenta assinar os apps por fora.")

                VStack(alignment: .leading, spacing: 8) {
                    instruction("1", "Conecte o LocalDevVPN e confirme que o iPhone tem internet.")
                    instruction("2", "Abra Atalhos, crie um atalho e adicione a ação do SideStore chamada “Refresh All Apps”.")
                    instruction("3", "Execute o atalho manualmente uma vez. Mantenha o LocalDevVPN conectado até o SideStore registrar sucesso no histórico.")
                    instruction("4", "Em Atalhos > Automação, crie uma automação diária por horário e selecione esse atalho. Escolha “Executar imediatamente”, se essa opção aparecer.")
                    instruction("5", "Escolha um horário em que o iPhone esteja ligado e com rede disponível. Confira periodicamente o histórico de renovações do SideStore.")
                }

                Text("Importante: o iOS pode adiar automações e tarefas em segundo plano. Sem internet, com LocalDevVPN desconectado ou se a execução for bloqueada pelo iOS, a renovação não acontece. A confirmação é o histórico do SideStore, não a mensagem inicial do Atalhos.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("A implementação atual do SideStore declara essa ação como ForegroundContinuableIntent e solicita continuação em primeiro plano se a operação ultrapassar cerca de 27 segundos. Portanto, o Atalhos pode trazer o SideStore para a frente; não há garantia de execução totalmente silenciosa ou sem desbloquear o iPhone.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("O AutoRenew ainda não consegue iniciar diretamente a App Intent privada de outro aplicativo. Esta integração usa o mecanismo oficial do SideStore por meio do Atalhos e exige configuração/consentimento no iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link(
                    "Ver a implementação oficial do SideStore",
                    destination: URL(string: "https://github.com/SideStore/SideStore/blob/develop/AltStore/Intents/App%20Intents/RefreshAllAppsIntent.swift")!
                )
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
            Text(text)
                .font(.caption)
        }
    }
}
