// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct FastScrollStrings {
    let title: String
    let caption: String
    let hubDescription: String
    let panelCaptionFormat: String
    let modifierLabel: String
    let keyOption: String
    let keyCommand: String
    let keyControl: String
    let keyFn: String
    let multiplierLabel: String
    let devicesLabel: String
    let mouseToggle: String
    let trackpadToggle: String
    let conflictNote: String

    func name(_ modifier: FastScrollModifier) -> String {
        switch modifier {
        case .option: return keyOption
        case .command: return keyCommand
        case .control: return keyControl
        case .fn: return keyFn
        }
    }

    func panelCaption(_ modifier: FastScrollModifier) -> String {
        String(format: panelCaptionFormat, modifier.glyph)
    }
}

extension FeatureStrings {
    static func fastScroll(_ language: AppLanguage) -> FastScrollStrings {
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

extension FastScrollStrings {
    static let enUS = FastScrollStrings(
        title: "Fast scrolling",
        caption: "Hold a key while scrolling to move through long pages several times faster. Let go to scroll normally again.",
        hubDescription: "Hold Option while scrolling with the mouse or trackpad to scroll several times faster.",
        panelCaptionFormat: "Hold %@ while scrolling to go faster.",
        modifierLabel: "Key to hold",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Speed",
        devicesLabel: "Works with",
        mouseToggle: "Mouse wheel",
        trackpadToggle: "Trackpad",
        conflictNote: "This key is also set for horizontal scrolling or zoom, so they get in each other’s way. Pick a different key for one of them.")

    static let ptBR = FastScrollStrings(
        title: "Rolagem rápida",
        caption: "Segure uma tecla enquanto rola para percorrer páginas longas várias vezes mais rápido. Solte para rolar normalmente de novo.",
        hubDescription: "Segure Option enquanto rola com o mouse ou o trackpad para rolar várias vezes mais rápido.",
        panelCaptionFormat: "Segure %@ ao rolar para ir mais rápido.",
        modifierLabel: "Tecla para segurar",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Velocidade",
        devicesLabel: "Funciona com",
        mouseToggle: "Rodinha do mouse",
        trackpadToggle: "Trackpad",
        conflictNote: "Esta tecla também está definida para rolagem horizontal ou zoom, então um atrapalha o outro. Escolha outra tecla para um deles.")

    static let tr = FastScrollStrings(
        title: "Hızlı kaydırma",
        caption: "Uzun sayfalarda birkaç kat daha hızlı ilerlemek için kaydırırken bir tuşu basılı tutun. Bırakınca normal kaydırma geri gelir.",
        hubDescription: "Fare veya trackpad ile kaydırırken Option tuşunu basılı tutarak birkaç kat daha hızlı kaydırın.",
        panelCaptionFormat: "Daha hızlı için kaydırırken %@ tuşunu tutun.",
        modifierLabel: "Basılı tutulacak tuş",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Hız",
        devicesLabel: "Şunlarla çalışır",
        mouseToggle: "Fare tekerleği",
        trackpadToggle: "Trackpad",
        conflictNote: "Bu tuş yatay kaydırma veya yakınlaştırma için de ayarlı, bu yüzden birbirlerine engel olurlar. Birisi için farklı bir tuş seçin.")

    static let ru = FastScrollStrings(
        title: "Быстрая прокрутка",
        caption: "Удерживайте клавишу во время прокрутки, чтобы листать длинные страницы в несколько раз быстрее. Отпустите, чтобы прокручивать как обычно.",
        hubDescription: "Удерживайте Option при прокрутке мышью или трекпадом, чтобы прокручивать в несколько раз быстрее.",
        panelCaptionFormat: "Удерживайте %@ при прокрутке для ускорения.",
        modifierLabel: "Клавиша",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Скорость",
        devicesLabel: "Работает с",
        mouseToggle: "Колесо мыши",
        trackpadToggle: "Трекпад",
        conflictNote: "Эта клавиша также задана для горизонтальной прокрутки или масштаба, и они мешают друг другу. Выберите для одного из них другую клавишу.")

    static let es = FastScrollStrings(
        title: "Desplazamiento rápido",
        caption: "Mantén pulsada una tecla mientras te desplazas para recorrer páginas largas varias veces más rápido. Suéltala para volver a la velocidad normal.",
        hubDescription: "Mantén pulsada Opción al desplazarte con el ratón o el trackpad para ir varias veces más rápido.",
        panelCaptionFormat: "Mantén %@ al desplazarte para ir más rápido.",
        modifierLabel: "Tecla que mantener",
        keyOption: "Opción",
        keyCommand: "Comando",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Velocidad",
        devicesLabel: "Funciona con",
        mouseToggle: "Rueda del ratón",
        trackpadToggle: "Trackpad",
        conflictNote: "Esta tecla también está asignada al desplazamiento horizontal o al zoom, así que se estorban. Elige otra tecla para uno de ellos.")

    static let sk = FastScrollStrings(
        title: "Rýchle rolovanie",
        caption: "Podržte počas rolovania kláves a dlhé stránky prejdete niekoľkonásobne rýchlejšie. Po pustení sa roluje normálne.",
        hubDescription: "Podržte Option pri rolovaní myšou alebo trackpadom a rolujte niekoľkonásobne rýchlejšie.",
        panelCaptionFormat: "Pre rýchlejšie rolovanie podržte %@.",
        modifierLabel: "Kláves na podržanie",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Rýchlosť",
        devicesLabel: "Funguje s",
        mouseToggle: "Koliesko myši",
        trackpadToggle: "Trackpad",
        conflictNote: "Tento kláves je nastavený aj na vodorovné rolovanie alebo zväčšenie, takže si prekážajú. Pre jedno z nich zvoľte iný kláves.")

    static let de = FastScrollStrings(
        title: "Schnelles Scrollen",
        caption: "Halte beim Scrollen eine Taste gedrückt, um lange Seiten um ein Vielfaches schneller zu durchlaufen. Loslassen scrollt wieder normal.",
        hubDescription: "Halte beim Scrollen mit Maus oder Trackpad die Wahltaste gedrückt, um um ein Vielfaches schneller zu scrollen.",
        panelCaptionFormat: "Halte beim Scrollen %@ für mehr Tempo.",
        modifierLabel: "Taste zum Halten",
        keyOption: "Wahltaste",
        keyCommand: "Befehlstaste",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Tempo",
        devicesLabel: "Funktioniert mit",
        mouseToggle: "Mausrad",
        trackpadToggle: "Trackpad",
        conflictNote: "Diese Taste ist auch für horizontales Scrollen oder Zoomen eingestellt, daher kommen sie sich in die Quere. Wähle für eines davon eine andere Taste.")

    static let fr = FastScrollStrings(
        title: "Défilement rapide",
        caption: "Maintenez une touche pendant le défilement pour parcourir les longues pages plusieurs fois plus vite. Relâchez pour défiler normalement.",
        hubDescription: "Maintenez Option en faisant défiler avec la souris ou le trackpad pour aller plusieurs fois plus vite.",
        panelCaptionFormat: "Maintenez %@ en défilant pour aller plus vite.",
        modifierLabel: "Touche à maintenir",
        keyOption: "Option",
        keyCommand: "Commande",
        keyControl: "Contrôle",
        keyFn: "Fn",
        multiplierLabel: "Vitesse",
        devicesLabel: "Fonctionne avec",
        mouseToggle: "Molette de la souris",
        trackpadToggle: "Trackpad",
        conflictNote: "Cette touche sert aussi au défilement horizontal ou au zoom, ils se gênent donc. Choisissez une autre touche pour l’un d’eux.")

    static let it = FastScrollStrings(
        title: "Scorrimento rapido",
        caption: "Tieni premuto un tasto mentre scorri per attraversare le pagine lunghe molto più in fretta. Rilascialo per scorrere di nuovo normalmente.",
        hubDescription: "Tieni premuto Opzione mentre scorri con mouse o trackpad per scorrere più volte più veloce.",
        panelCaptionFormat: "Tieni %@ mentre scorri per andare più veloce.",
        modifierLabel: "Tasto da tenere premuto",
        keyOption: "Opzione",
        keyCommand: "Comando",
        keyControl: "Controllo",
        keyFn: "Fn",
        multiplierLabel: "Velocità",
        devicesLabel: "Funziona con",
        mouseToggle: "Rotellina del mouse",
        trackpadToggle: "Trackpad",
        conflictNote: "Questo tasto è impostato anche per lo scorrimento orizzontale o lo zoom, quindi si ostacolano. Scegli un altro tasto per uno dei due.")

    static let ja = FastScrollStrings(
        title: "高速スクロール",
        caption: "スクロール中にキーを押したままにすると、長いページを数倍速く移動できます。離すと通常の速さに戻ります。",
        hubDescription: "マウスやトラックパッドでスクロールするときに Option キーを押したままにすると、数倍速くスクロールします。",
        panelCaptionFormat: "スクロール中に %@ を押すと速くなります。",
        modifierLabel: "押すキー",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "速さ",
        devicesLabel: "対象",
        mouseToggle: "マウスホイール",
        trackpadToggle: "トラックパッド",
        conflictNote: "このキーは横スクロールまたはズームにも設定されているため、互いに干渉します。どちらかに別のキーを選んでください。")

    static let ko = FastScrollStrings(
        title: "빠른 스크롤",
        caption: "스크롤하는 동안 키를 누르고 있으면 긴 페이지를 몇 배 더 빠르게 넘길 수 있습니다. 키를 떼면 다시 보통 속도로 스크롤합니다.",
        hubDescription: "마우스나 트랙패드로 스크롤할 때 Option 키를 누르고 있으면 몇 배 더 빠르게 스크롤합니다.",
        panelCaptionFormat: "스크롤할 때 %@ 키를 누르면 더 빠릅니다.",
        modifierLabel: "누를 키",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "속도",
        devicesLabel: "적용 대상",
        mouseToggle: "마우스 휠",
        trackpadToggle: "트랙패드",
        conflictNote: "이 키는 가로 스크롤이나 확대/축소에도 지정되어 있어 서로 방해합니다. 둘 중 하나에 다른 키를 고르세요.")

    static let zhHans = FastScrollStrings(
        title: "快速滚动",
        caption: "滚动时按住一个键，浏览长页面的速度会快好几倍。松开后恢复正常滚动。",
        hubDescription: "用鼠标或触控板滚动时按住 Option 键，滚动速度快好几倍。",
        panelCaptionFormat: "滚动时按住 %@ 可加快速度。",
        modifierLabel: "按住的键",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "速度",
        devicesLabel: "适用于",
        mouseToggle: "鼠标滚轮",
        trackpadToggle: "触控板",
        conflictNote: "此键也被设置用于水平滚动或缩放，两者会互相干扰。请为其中一个选择其他键。")

    static let zhTW = FastScrollStrings(
        title: "快速捲動",
        caption: "捲動時按住一個按鍵，瀏覽長頁面的速度會快好幾倍。放開後恢復正常捲動。",
        hubDescription: "用滑鼠或觸控式軌跡板捲動時按住 Option 鍵，捲動速度快好幾倍。",
        panelCaptionFormat: "捲動時按住 %@ 可加快速度。",
        modifierLabel: "按住的按鍵",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "速度",
        devicesLabel: "適用於",
        mouseToggle: "滑鼠滾輪",
        trackpadToggle: "觸控式軌跡板",
        conflictNote: "此按鍵也設定用於水平捲動或縮放，兩者會互相干擾。請為其中一個選擇其他按鍵。")

    static let zhHK = FastScrollStrings(
        title: "快速捲動",
        caption: "捲動時按住一個鍵，睇長頁面會快好多倍。放開就回復正常捲動。",
        hubDescription: "用滑鼠或觸控板捲動時按住 Option 鍵，捲動快好多倍。",
        panelCaptionFormat: "捲動時按住 %@ 可以加快。",
        modifierLabel: "要按住嘅鍵",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "速度",
        devicesLabel: "適用於",
        mouseToggle: "滑鼠滾輪",
        trackpadToggle: "觸控板",
        conflictNote: "呢個鍵亦設定咗做水平捲動或縮放，兩者會互相干擾。請為其中一個揀第二個鍵。")

    static let uk = FastScrollStrings(
        title: "Швидке прокручування",
        caption: "Утримуйте клавішу під час прокручування, щоб гортати довгі сторінки в кілька разів швидше. Відпустіть, щоб прокручувати як зазвичай.",
        hubDescription: "Утримуйте Option під час прокручування мишею або трекпадом, щоб прокручувати в кілька разів швидше.",
        panelCaptionFormat: "Утримуйте %@ під час прокручування для пришвидшення.",
        modifierLabel: "Клавіша",
        keyOption: "Option",
        keyCommand: "Command",
        keyControl: "Control",
        keyFn: "Fn",
        multiplierLabel: "Швидкість",
        devicesLabel: "Працює з",
        mouseToggle: "Коліщатко миші",
        trackpadToggle: "Трекпад",
        conflictNote: "Цю клавішу також задано для горизонтального прокручування або масштабу, тож вони заважають одне одному. Виберіть для одного з них іншу клавішу.")
}
