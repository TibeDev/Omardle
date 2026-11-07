function pad2(value) {
    return (value < 10 ? "0" : "") + value
}

function dateKey(date) {
    return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function utcDateKey(date) {
    return date.getUTCFullYear() + "-" + pad2(date.getUTCMonth() + 1) + "-" + pad2(date.getUTCDate())
}

function parseDateKey(key) {
    var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key || ""))
    if (!match)
        return null

    var year = Number(match[1])
    var month = Number(match[2])
    var day = Number(match[3])
    var date = new Date(Date.UTC(year, month - 1, day))
    if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day)
        return null

    return date
}

function isPuzzleDate(key, todayKey) {
    var date = parseDateKey(key)
    var today = parseDateKey(todayKey)
    return !!date && !!today && key >= "2021-06-19" && key <= todayKey
}

function monthKey(year, month) {
    return utcDateKey(new Date(Date.UTC(year, month, 1))).slice(0, 7)
}

function shiftMonth(year, month, offset) {
    var date = new Date(Date.UTC(year, month + offset, 1))
    return { year: date.getUTCFullYear(), month: date.getUTCMonth() }
}

function monthGrid(year, month) {
    var first = new Date(Date.UTC(year, month, 1))
    var leading = (first.getUTCDay() + 6) % 7
    var days = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()
    var cells = []

    for (var i = 0; i < 42; i++) {
        var day = i - leading + 1
        if (day < 1 || day > days) {
            cells.push({ key: "", day: "" })
        } else {
            var date = new Date(Date.UTC(year, month, day))
            cells.push({ key: utcDateKey(date), day: String(day) })
        }
    }

    return cells
}

function evaluateGuess(answer, guess) {
    var solution = String(answer || "").toLowerCase()
    var attempt = String(guess || "").toLowerCase()
    var result = ["absent", "absent", "absent", "absent", "absent"]
    var remaining = {}

    for (var i = 0; i < 5; i++) {
        if (attempt.charAt(i) === solution.charAt(i)) {
            result[i] = "correct"
        } else {
            var letter = solution.charAt(i)
            remaining[letter] = (remaining[letter] || 0) + 1
        }
    }

    for (var j = 0; j < 5; j++) {
        if (result[j] === "correct")
            continue
        var guessLetter = attempt.charAt(j)
        if (remaining[guessLetter] > 0) {
            result[j] = "present"
            remaining[guessLetter]--
        }
    }

    return result
}

function normalizeGame(value) {
    if (!value || typeof value !== "object" || !Array.isArray(value.guesses))
        return { guesses: [], finished: false, won: false }

    var guesses = []
    for (var i = 0; i < Math.min(6, value.guesses.length); i++) {
        var guess = String(value.guesses[i] || "").toLowerCase()
        if (/^[a-z]{5}$/.test(guess))
            guesses.push(guess)
    }

    var won = value.won === true && guesses.length > 0
        && guesses[guesses.length - 1] === String(value.answer || "").toLowerCase()
    var finished = value.finished === true || won || guesses.length >= 6
    return { guesses: guesses, finished: finished, won: won }
}
