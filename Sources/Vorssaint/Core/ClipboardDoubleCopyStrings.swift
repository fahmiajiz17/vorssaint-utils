// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardDoubleCopyStrings {
    let toggle: String
    let caption: String
}

extension FeatureStrings {
    static func clipboardDoubleCopy(_ language: AppLanguage) -> ClipboardDoubleCopyStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension ClipboardDoubleCopyStrings {
    static let enUS = ClipboardDoubleCopyStrings(
        toggle: "Open history with ⌘ + C + C",
        caption: "Hold ⌘ and press C twice quickly to copy and open the history. Works alongside the shortcut above."
    )

    static let ptBR = ClipboardDoubleCopyStrings(
        toggle: "Abrir histórico com ⌘ + C + C",
        caption: "Segure ⌘ e pressione C duas vezes rapidamente para copiar e abrir o histórico. Funciona junto com o atalho acima."
    )

    static let tr = ClipboardDoubleCopyStrings(
        toggle: "Geçmişi ⌘ + C + C ile aç",
        caption: "Kopyalayıp geçmişi açmak için ⌘ tuşunu basılı tutup C’ye hızla iki kez basın. Yukarıdaki kısayolla birlikte çalışır."
    )

    static let ru = ClipboardDoubleCopyStrings(
        toggle: "Открывать историю по ⌘ + C + C",
        caption: "Удерживайте ⌘ и быстро дважды нажмите C, чтобы скопировать и открыть историю. Работает вместе с сочетанием выше."
    )

    static let es = ClipboardDoubleCopyStrings(
        toggle: "Abrir el historial con ⌘ + C + C",
        caption: "Mantén ⌘ y pulsa C dos veces rápido para copiar y abrir el historial. Funciona junto con el atajo de arriba."
    )

    static let sk = ClipboardDoubleCopyStrings(
        toggle: "Otvoriť históriu cez ⌘ + C + C",
        caption: "Podržte ⌘ a rýchlo dvakrát stlačte C, čím skopírujete a otvoríte históriu. Funguje spolu so skratkou vyššie."
    )

    static let de = ClipboardDoubleCopyStrings(
        toggle: "Verlauf mit ⌘ + C + C öffnen",
        caption: "Halte ⌘ und drücke zweimal schnell C, um zu kopieren und den Verlauf zu öffnen. Funktioniert zusätzlich zum Kurzbefehl oben."
    )

    static let fr = ClipboardDoubleCopyStrings(
        toggle: "Ouvrir l’historique avec ⌘ + C + C",
        caption: "Maintenez ⌘ et appuyez deux fois rapidement sur C pour copier et ouvrir l’historique. Fonctionne en plus du raccourci ci-dessus."
    )

    static let it = ClipboardDoubleCopyStrings(
        toggle: "Apri la cronologia con ⌘ + C + C",
        caption: "Tieni premuto ⌘ e premi C due volte rapidamente per copiare e aprire la cronologia. Funziona insieme alla scorciatoia sopra."
    )

    static let ja = ClipboardDoubleCopyStrings(
        toggle: "⌘ + C + C で履歴を開く",
        caption: "⌘ を押したまま C を素早く 2 回押すと、コピーして履歴を開きます。上のショートカットと併用できます。"
    )

    static let ko = ClipboardDoubleCopyStrings(
        toggle: "⌘ + C + C로 기록 열기",
        caption: "⌘를 누른 채 C를 빠르게 두 번 누르면 복사하고 기록을 엽니다. 위의 단축키와 함께 사용할 수 있습니다."
    )

    static let zhHans = ClipboardDoubleCopyStrings(
        toggle: "使用 ⌘ + C + C 打开历史记录",
        caption: "按住 ⌘ 并快速按两次 C，即可拷贝并打开历史记录。可与上方的快捷键同时使用。"
    )

    static let zhTW = ClipboardDoubleCopyStrings(
        toggle: "使用 ⌘ + C + C 打開歷史記錄",
        caption: "按住 ⌘ 並快速按兩次 C，即可拷貝並打開歷史記錄。可與上方的快速鍵同時使用。"
    )

    static let zhHK = ClipboardDoubleCopyStrings(
        toggle: "使用 ⌘ + C + C 打開歷史記錄",
        caption: "按住 ⌘ 並快速按兩次 C，即可拷貝並打開歷史記錄。可與上方的快速鍵同時使用。"
    )

    static let uk = ClipboardDoubleCopyStrings(
        toggle: "Відкривати історію через ⌘ + C + C",
        caption: "Утримуйте ⌘ і швидко двічі натисніть C, щоб скопіювати й відкрити історію. Працює разом із сполученням вище."
    )
}
