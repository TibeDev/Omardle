pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model
import "Dictionary.js" as Dictionary

Panel {
    id: root

    moduleName: "tibevdb.wordle"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property string selectedDate: ""
    property string answer: ""
    property string requestedDate: ""
    property string statusMessage: ""
    property bool loading: false
    property bool showingCalendar: false
    property bool stateReady: false
    property string lastKnownToday: ""
    property var savedGames: ({})
    property int calendarYear: new Date().getFullYear()
    property int calendarMonth: new Date().getMonth()

    readonly property string todayKey: Model.dateKey(clock.date)
    readonly property color controlBackground: Commons.Color.popups.background
    readonly property var currentGame: Model.normalizeGame(savedGames[selectedDate])
    readonly property var calendarCells: Model.monthGrid(calendarYear, calendarMonth)
    readonly property var weekdayLabels: {
        var locale = Qt.locale(Commons.I18n.formatLocale)
        var weekdays = [1, 2, 3, 4, 5, 6, 0]
        var labels = []
        for (var i = 0; i < weekdays.length; i++)
            labels.push(String(locale.dayName(weekdays[i], Locale.ShortFormat)).replace(/\.$/, "").toUpperCase())
        return labels
    }

    function open() {
        if (selectedDate === "" || selectedDate > todayKey)
            loadDate(todayKey)
        root.controller.show()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.open()
    }

    function closeForPopoutSwitch() {
        root.popoutSwitchClosing = true
        root.close()
        Qt.callLater(function() { root.popoutSwitchClosing = false })
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    function injectPanel() {
        panel.bar = root.bar
        panel.anchorItem = root.anchorItem
        panel.owner = root.hostWidget || root
    }

    function loadDate(key) {
        var date = String(key || "")
        if (!Model.isPuzzleDate(date, todayKey)) {
            statusMessage = "Choose a date from 2021-06-19 through " + todayKey + "."
            return
        }

        if (fetchProc.running)
            fetchProc.running = false

        selectedDate = date
        answer = ""
        guessInput.text = ""
        statusMessage = ""
        loading = true
        requestedDate = date
        fetchProc.command = [
            "curl", "-fsS", "--max-time", "8", "--max-filesize", "4096",
            "--max-redirs", "0", "--proto", "=https",
            "https://www.nytimes.com/svc/wordle/v2/" + date + ".json"
        ]
        fetchProc.running = true
    }

    function applySavedState(raw) {
        stateReady = true
        if (!raw || String(raw).length > 131072) {
            savedGames = ({})
            return
        }
        try {
            var parsed = JSON.parse(raw)
            var sanitized = ({})
            if (parsed && parsed.version === 1 && parsed.games && typeof parsed.games === "object") {
                for (var key in parsed.games) {
                    if (Model.isPuzzleDate(key, todayKey))
                        sanitized[key] = Model.normalizeGame(parsed.games[key])
                }
            }
            savedGames = sanitized
        } catch (e) {
            savedGames = ({})
        }
    }

    function persistGames() {
        if (!stateReady)
            return
        var payload = JSON.stringify({ version: 1, games: savedGames })
        if (payload.length <= 131072)
            stateFile.setText(payload)
    }

    function saveCurrentGame(guesses, finished, won) {
        var updated = ({})
        for (var key in savedGames)
            updated[key] = savedGames[key]
        updated[selectedDate] = { guesses: guesses, finished: finished, won: won, answer: answer }
        savedGames = updated
        persistGames()
    }

    function submitGuess() {
        if (loading || answer === "" || currentGame.finished)
            return

        var guess = String(guessInput.text || "").toLowerCase()
        if (!/^[a-z]{5}$/.test(guess)) {
            statusMessage = "Enter five letters."
            return
        }
        if (!Dictionary.isValidGuess(guess) && guess !== answer) {
            statusMessage = "Not in the offline word list."
            return
        }
        var guesses = currentGame.guesses.slice()
        guesses.push(guess)
        var won = guess === answer
        var finished = won || guesses.length >= 6
        saveCurrentGame(guesses, finished, won)
        guessInput.text = ""
        statusMessage = won ? "Solved in " + guesses.length + (guesses.length === 1 ? " guess." : " guesses.")
            : finished ? "Answer: " + answer.toUpperCase() : ""
    }

    function cellLetter(row, column) {
        var game = currentGame
        if (row < game.guesses.length)
            return game.guesses[row].charAt(column).toUpperCase()
        if (row === game.guesses.length && !game.finished)
            return String(guessInput.text || "").toUpperCase().charAt(column)
        return ""
    }

    function cellState(row, column) {
        var game = currentGame
        if (row >= game.guesses.length || answer === "")
            return "empty"
        return Model.evaluateGuess(answer, game.guesses[row])[column]
    }

    function openCalendar() {
        var date = Model.parseDateKey(selectedDate || todayKey)
        if (!date)
            date = Model.parseDateKey(todayKey)
        calendarYear = date.getUTCFullYear()
        calendarMonth = date.getUTCMonth()
        showingCalendar = true
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    function closeCalendar() {
        showingCalendar = false
        Qt.callLater(function() { guessInput.forceActiveFocus() })
    }

    function moveCalendarMonth(offset) {
        var next = Model.shiftMonth(calendarYear, calendarMonth, offset)
        var key = Model.monthKey(next.year, next.month)
        if (key < "2021-06" || key > todayKey.slice(0, 7))
            return
        calendarYear = next.year
        calendarMonth = next.month
    }

    function selectCalendarDate(key) {
        if (!Model.isPuzzleDate(key, todayKey))
            return
        showingCalendar = false
        loadDate(key)
        Qt.callLater(function() { guessInput.forceActiveFocus() })
    }

    function appendLetter(value) {
        if (showingCalendar || guessInput.activeFocus || loading || currentGame.finished)
            return
        var letter = String(value || "").toLowerCase()
        if (/^[a-z]$/.test(letter) && guessInput.text.length < 5)
            guessInput.text += letter
    }

    function removeLetter() {
        if (showingCalendar || guessInput.activeFocus || guessInput.text.length === 0)
            return
        guessInput.text = guessInput.text.slice(0, -1)
    }

    onBarChanged: injectPanel()
    onAnchorItemChanged: injectPanel()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        onDateChanged: {
            var newToday = Model.dateKey(date)
            if (root.lastKnownToday !== "" && root.selectedDate === root.lastKnownToday)
                root.loadDate(newToday)
            root.lastKnownToday = newToday
        }
    }

    Process {
        id: ensureStateDir
        command: ["mkdir", "-p", root.stateDir]
        onExited: stateFile.reload()
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.loading = false
                var raw = String(text || "").trim()
                if (!raw || raw.length > 4096) {
                    root.statusMessage = "Could not load this puzzle. Check connection and retry."
                    return
                }
                try {
                    var data = JSON.parse(raw)
                    var solution = String(data.solution || "").toLowerCase()
                    if (data.print_date !== root.requestedDate || !/^[a-z]{5}$/.test(solution)) {
                        root.statusMessage = "NYT returned invalid puzzle data."
                        return
                    }
                    root.answer = solution
                    var previous = root.savedGames[root.selectedDate]
                    var game = Model.normalizeGame(previous)
                    if (game.guesses.length > 0 && game.guesses[game.guesses.length - 1] === solution)
                        game.won = true
                    root.statusMessage = game.won ? "Solved in " + game.guesses.length + (game.guesses.length === 1 ? " guess." : " guesses.")
                        : game.finished ? "Answer: " + solution.toUpperCase() : ""
                } catch (e) {
                    root.statusMessage = "Could not read NYT puzzle data."
                }
            }
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: root.applySavedState(text())
        onLoadFailed: root.applySavedState("")
    }

    Component.onCompleted: {
        lastKnownToday = todayKey
        ensureStateDir.running = true
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: root.showingCalendar ? keyCatcher : guessInput
        contentWidth: panel.fittedContentWidth(Style.space(430))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: guessInput.activeFocus
            onCloseRequested: {
                if (root.showingCalendar)
                    root.closeCalendar()
                else
                    root.close()
            }
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onTextKey: function(text) { root.appendLetter(text) }
            onDeleteRequested: root.removeLetter()
            onReturnRequested: {
                if (!root.showingCalendar)
                    root.submitGuess()
            }

            ColumnLayout {
                id: content
                width: parent.width
                spacing: Style.space(8)

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.showingCalendar
                    Text {
                        textFormat: Text.PlainText
                        text: "Wordle"
                        color: root.barForeground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.title
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Text {
                        textFormat: Text.PlainText
                        text: root.selectedDate || root.todayKey
                        color: Qt.alpha(root.barForeground, 0.72)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.small
                    }
                    Rectangle {
                        implicitWidth: Style.space(34)
                        implicitHeight: Style.space(34)
                        radius: Style.space(6)
                        color: calendarButton.pressed
                            ? Qt.alpha(root.barForeground, 0.2)
                            : "transparent"
                        Text {
                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: "▦"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.title
                        }
                        MouseArea {
                            id: calendarButton
                            anchors.fill: parent
                            onClicked: root.openCalendar()
                        }
                        ToolTip.visible: calendarButton.containsMouse
                        ToolTip.text: "Choose date"
                        ToolTip.delay: 500
                    }
                }

                GridLayout {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 5
                    columnSpacing: Style.space(4)
                    rowSpacing: Style.space(4)
                    visible: !root.showingCalendar
                    Repeater {
                        model: 30
                        delegate: Rectangle {
                            required property int index
                            readonly property int rowIndex: Math.floor(index / 5)
                            readonly property int columnIndex: index % 5
                            readonly property string cellResult: root.cellState(rowIndex, columnIndex)
                            Layout.preferredWidth: Style.space(46)
                            Layout.preferredHeight: Style.space(46)
                            radius: Style.space(4)
                            color: cellResult === "correct" ? "#6aaa64"
                                : cellResult === "present" ? "#c9b458"
                                : cellResult === "absent" ? "#787c7e"
                                : "transparent"
                            border.color: cellResult === "empty" ? Qt.alpha(root.barForeground, 0.35) : color
                            border.width: 2
                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: root.cellLetter(parent.rowIndex, parent.columnIndex)
                                color: parent.cellResult === "empty" ? root.barForeground : "white"
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.title
                                font.bold: true
                            }
                        }
                    }
                }

                TextInput {
                    id: guessInput
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    opacity: 0
                    enabled: !root.showingCalendar
                    maximumLength: 5
                    validator: RegularExpressionValidator { regularExpression: /[A-Za-z]{0,5}/ }
                    Keys.onReturnPressed: root.submitGuess()
                    Keys.onEscapePressed: root.close()
                    Keys.onTabPressed: root.switchPanel(1)
                    onTextChanged: {
                        if (!root.currentGame.finished)
                            root.statusMessage = ""
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: root.statusMessage
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.small
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    visible: !root.showingCalendar && text !== ""
                }

                ColumnLayout {
                    id: calendarPage
                    visible: root.showingCalendar
                    Layout.fillWidth: true
                    spacing: Style.space(10)

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: "Choose Wordle date"
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.title
                            font.bold: true
                        }
                        Rectangle {
                            implicitWidth: Style.space(34)
                            implicitHeight: Style.space(34)
                            radius: Style.space(6)
                            color: closeCalendarButton.pressed
                                ? Qt.alpha(root.barForeground, 0.2)
                                : "transparent"
                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: "×"
                                color: root.barForeground
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.title
                            }
                            MouseArea {
                                id: closeCalendarButton
                                anchors.fill: parent
                                onClicked: root.closeCalendar()
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            implicitWidth: Style.space(36)
                            implicitHeight: Style.space(34)
                            radius: Style.space(6)
                            opacity: Model.monthKey(root.calendarYear, root.calendarMonth) > "2021-06" ? 1 : 0.35
                            color: previousMonthMouse.pressed ? Qt.alpha(root.barForeground, 0.2) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: "‹"
                                color: root.barForeground
                                font.pixelSize: Style.font.title
                            }
                            MouseArea {
                                id: previousMonthMouse
                                anchors.fill: parent
                                enabled: Model.monthKey(root.calendarYear, root.calendarMonth) > "2021-06"
                                onClicked: root.moveCalendarMonth(-1)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: Qt.locale(Commons.I18n.formatLocale).monthName(root.calendarMonth + 1, Locale.LongFormat)
                                + " " + root.calendarYear
                            color: root.barForeground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.body
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            implicitWidth: Style.space(36)
                            implicitHeight: Style.space(34)
                            radius: Style.space(6)
                            opacity: Model.monthKey(root.calendarYear, root.calendarMonth) < root.todayKey.slice(0, 7) ? 1 : 0.35
                            color: nextMonthMouse.pressed ? Qt.alpha(root.barForeground, 0.2) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: "›"
                                color: root.barForeground
                                font.pixelSize: Style.font.title
                            }
                            MouseArea {
                                id: nextMonthMouse
                                anchors.fill: parent
                                enabled: Model.monthKey(root.calendarYear, root.calendarMonth) < root.todayKey.slice(0, 7)
                                onClicked: root.moveCalendarMonth(1)
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: Style.space(3)
                        rowSpacing: Style.space(3)

                        Repeater {
                            model: root.weekdayLabels
                            delegate: Text {
                                required property string modelData
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                textFormat: Text.PlainText
                                text: modelData
                                color: Qt.alpha(root.barForeground, 0.65)
                                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                font.pixelSize: Style.font.small
                                font.bold: true
                            }
                        }

                        Repeater {
                            model: root.calendarCells
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selectable: Model.isPuzzleDate(modelData.key, root.todayKey)
                                Layout.fillWidth: true
                                Layout.preferredHeight: Style.space(36)
                                radius: Style.space(6)
                                color: modelData.key === root.selectedDate
                                    ? Commons.Color.accent
                                    : dayMouse.pressed ? Qt.alpha(root.barForeground, 0.18) : "transparent"
                                opacity: selectable || modelData.day === "" ? 1 : 0.3
                                Text {
                                    anchors.centerIn: parent
                                    textFormat: Text.PlainText
                                    text: modelData.day
                                    color: modelData.key === root.selectedDate ? Commons.Color.popups.background : root.barForeground
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.body
                                    font.bold: modelData.key === root.todayKey
                                }
                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    enabled: parent.selectable
                                    onClicked: root.selectCalendarDate(modelData.key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property string stateDir: (Quickshell.env("HOME") || "") + "/.local/state/omarchy"
    readonly property string statePath: stateDir + "/wordle-games.json"
}
