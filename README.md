# Omarchy Wordle

Play the NYT daily Wordle from an Omarchy bar popup. Type guesses while the popup has focus. Use the calendar button to select any puzzle date from June 19, 2021 through today.

Puzzle answers load from `https://www.nytimes.com/svc/wordle/v2/YYYY-MM-DD.json` when the panel opens or when a date changes. Guesses and completion state stay in `~/.local/state/omarchy/wordle-games.json`.

The offline guess list is bundled in `Dictionary.js`. It comes from the MIT-licensed `darkermango/5-Letter-words` list; `tools/build_dictionary.py` refreshes it.

Run model checks with `node tests/model.test.js`.
