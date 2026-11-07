const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const pluginRoot = path.resolve(__dirname, "..");
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(pluginRoot, "Model.js"), "utf8"), context);
vm.runInContext(fs.readFileSync(path.join(pluginRoot, "Dictionary.js"), "utf8"), context);

assert.deepEqual(
  Array.from(context.evaluateGuess("eerie", "refer")),
  ["present", "correct", "absent", "present", "absent"],
);
assert.equal(context.isValidGuess("prate"), true);
assert.equal(context.isValidGuess("zzzzz"), false);
assert.equal(context.isPuzzleDate("2021-06-19", "2026-11-07"), true);
assert.equal(context.isPuzzleDate("2021-06-18", "2026-11-07"), false);
assert.equal(context.isPuzzleDate("2026-11-08", "2026-11-07"), false);
assert.equal(context.monthKey(2021, 5), "2021-06");
assert.deepEqual(
  [context.shiftMonth(2021, 5, -1).year, context.shiftMonth(2021, 5, -1).month],
  [2021, 4],
);
const june2021 = Array.from(context.monthGrid(2021, 5), (cell) => [cell.key, cell.day]);
assert.equal(june2021.length, 42);
assert.deepEqual(june2021[0], ["", ""]);
assert.deepEqual(june2021[1], ["2021-06-01", "1"]);
assert.equal(june2021.filter((cell) => cell[0] !== "").length, 30);

console.log("Wordle model checks passed");
