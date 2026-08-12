local root = (... and (...):match("^(.*)[/\\]")) or "."
local entry = assert(loadfile(root .. "/../main.lua"))()

local capturedHook
local capturedDexCommand
local capturedGameReady
local vanillaDexCalls = 0
local vanillaDexCommand = function()
  vanillaDexCalls = vanillaDexCalls + 1
end
local store = {}
local fakeMod = {
  content = {
    pokemon = { get = function() return { name = "TESTMON" } end },
    commands = {
      get = function(_, id)
        assert(id == "dex_rating")
        return vanillaDexCommand
      end,
      override = function(_, id, fn)
        assert(id == "dex_rating")
        capturedDexCommand = fn
        return fn
      end,
    },
  },
  hooks = { wrap = function(_, name, fn)
    if name == "ui.pc.items" then capturedHook = fn end
  end },
  events = { on = function(_, name, fn)
    if name == "game.ready" then capturedGameReady = fn end
  end },
  ui = {},
  save = {
    get = function(_, k, d) local v = store[k]; if v == nil then return d end; return v end,
    set = function(_, k, v) store[k] = v end,
  },
  exports = {},
}
entry(fakeMod)
assert(capturedGameReady, "game.ready listener was not registered")
-- Gen 1 integration is deliberately deferred until the live generation is known.
capturedGameReady({ game = { data = {} } })
assert(capturedHook, "ui.pc.items hook was not registered")
assert(capturedDexCommand, "dex_rating command override was not registered")
assert(fakeMod.exports.version == "2.0.0")

-- Any dex_rating command outside Oak's Lab is delegated untouched.
capturedDexCommand({ overworld = { map = { id = "OTHER_MAP" } } })
assert(vanillaDexCalls == 1)

local function mon(dvs, statExp)
  return { dvs = dvs or {}, statExp = statExp or {} }
end

local function allStatExp(v)
  return { hp = v, attack = v, defense = v, speed = v, special = v }
end

-- DV thresholds: 0..60, HP is deliberately not counted.
assert(fakeMod.exports.scoreDVs(mon({attack=15, defense=15, speed=15, special=15})).tier == "outstanding")
assert(fakeMod.exports.scoreDVs(mon({attack=15, defense=15, speed=10, special=10})).sum == 50)
assert(fakeMod.exports.scoreDVs(mon({attack=15, defense=15, speed=10, special=9})).tier == "above_average") -- 49
assert(fakeMod.exports.scoreDVs(mon({attack=10, defense=10, speed=10, special=10})).tier == "above_average") -- 40
assert(fakeMod.exports.scoreDVs(mon({attack=10, defense=10, speed=10, special=9})).tier == "ordinary") -- 39
assert(fakeMod.exports.scoreDVs(mon({attack=8, defense=8, speed=8, special=7})).tier == "ordinary") -- 31
assert(fakeMod.exports.scoreDVs(mon({attack=8, defense=8, speed=7, special=7})).tier == "limited") -- 30

-- Gen I effective Stat Experience contribution boundaries.
assert(fakeMod.exports.effectiveStatExp(0) == 0)
assert(fakeMod.exports.effectiveStatExp(1) == 0)
assert(fakeMod.exports.effectiveStatExp(16) == 1)
assert(fakeMod.exports.effectiveStatExp(4096) == 16)
assert(fakeMod.exports.effectiveStatExp(16384) == 32)
assert(fakeMod.exports.effectiveStatExp(40000) == 50)
assert(fakeMod.exports.effectiveStatExp(63001) == 62)
assert(fakeMod.exports.effectiveStatExp(63002) == 63)
assert(fakeMod.exports.effectiveStatExp(65535) == 63)

assert(fakeMod.exports.scoreTraining(mon(nil, allStatExp(0))).tier == "starting")
assert(fakeMod.exports.scoreTraining(mon(nil, allStatExp(4096))).tier == "developing")
assert(fakeMod.exports.scoreTraining(mon(nil, allStatExp(16384))).tier == "well_trained")
assert(fakeMod.exports.scoreTraining(mon(nil, allStatExp(40000))).tier == "nearly_complete")
local perfect = fakeMod.exports.scoreTraining(mon(nil, allStatExp(65535)))
assert(perfect.sum == 315 and perfect.percent == 100 and perfect.tier == "complete")

-- The hook keeps unrelated PC rows and decorates only Oak's callback.
local calledVanilla = false
local inputRows = {
  { label = "BILL'S PC", onSelect = function() end },
  { label = "PROF.OAK's PC", keepOpen = true, onSelect = function() calledVanilla = true end },
}
local output = capturedHook(function(_, rows) return rows end, {}, inputRows)
assert(#output == 2)
assert(output[1] == inputRows[1])
assert(output[2] ~= inputRows[2])
assert(output[2].label == "PROF.OAK's PC" and output[2].keepOpen == true)
assert(type(output[2].onSelect) == "function")
assert(calledVanilla == false)

-- Exercise production-style width/splitting APIs with fixed 8px glyphs.
-- Gen1Recomp's real Font greedily treats <PK>, <MN>, and apostrophe
-- ligatures such as 's as single charmap glyphs. Model that contract here
-- instead of counting their ASCII source bytes.
fakeMod.ui.Theme = { textBox = { maxCols = 18 } }

local function fakeGlyphSpans(text)
  text = tostring(text or "")
  local spans = {}
  local i = 1
  while i <= #text do
    local len = 1
    if text:sub(i, i + 3) == "<PK>" or text:sub(i, i + 3) == "<MN>" then
      len = 4
    elseif text:sub(i, i + 1) == "'s" then
      len = 2
    end
    spans[#spans + 1] = { from = i, to = i + len - 1 }
    i = i + len
  end
  return spans
end

local function visibleCells(text)
  return #fakeGlyphSpans(text)
end

fakeMod.ui.Font = {
  width = function(text) return visibleCells(text) * 8 end,
  split = fakeGlyphSpans,
}

-- Requested hyphenation: use otherwise-wasted end-of-row space rather than
-- moving the whole word "potential" to the next row.
local layout = fakeMod.exports.layoutAppraisalText("Its potential is remarkable!")
assert(#layout == 1)
assert(layout[1] == "Its potential is\nremarkable!")
local hyphenLayout = fakeMod.exports.layoutAppraisalText("Great potential remains.")
assert(hyphenLayout[1] == "Great potential\nremains.")
for _, box in ipairs(layout) do
  assert(not box:find("\f", 1, true))
  local lineCount = 0
  for line in (box .. "\n"):gmatch("(.-)\n") do
    lineCount = lineCount + 1
    assert(visibleCells(line) <= 18, "line exceeded 18 visible cells: " .. line)
  end
  assert(lineCount <= 2, "physical appraisal box exceeded two lines")
end

-- A second representative phrase should remain compact without gratuitous
-- Experience hyphenation.
local statLayout = fakeMod.exports.layoutAppraisalText("Its stats are fully developed!")
assert(#statLayout == 1)
assert(statLayout[1] == "Its stats are\nfully developed!")

local developingFollowupLayout = fakeMod.exports.layoutAppraisalText("It still needs lots of training.")
assert(#developingFollowupLayout == 1)
assert(developingFollowupLayout[1] == "It still needs\nlots of training.")

local allSemanticMessages = {
  "Your <PK><MN>'s DVs are outstanding!",
  "Its potential is remarkable!",
  "Your <PK><MN>'s DVs are very good.",
  "Its potential is above average.",
  "Your <PK><MN>'s DVs are fairly ordinary.",
  "Its natural potential is decent.",
  "Your <PK><MN>'s DVs are rather low.",
  "Its natural potential is limited.",
  "Its stats are fully developed!",
  "It reached its full potential!",
  "Its stats are remarkably high!",
  "It's very near its full potential.",
  "Its stats show lots of training.",
  "It still has room to grow!",
  "Its stats are growing nicely.",
  "It still needs lots of training.",
  "Its stats are still quite low.",
  "You two are just getting started!",
}
-- Lock the agreed visible copy to the actual source, not only to the test fixture.
local sourceFile = assert(io.open(root .. "/../main.lua", "r"))
local sourceText = sourceFile:read("*a")
sourceFile:close()
for _, message in ipairs(allSemanticMessages) do
  if not message:find("Your <PK><MN>'s", 1, true) then
    assert(sourceText:find(message, 1, true), "agreed appraisal copy missing from main.lua: " .. message)
  end
end
assert(sourceText:find([[local PKMN_POSSESSIVE = "<PK><MN>'s"]], 1, true))
for _, suffix in ipairs({
  " DVs are outstanding!",
  " DVs are very good.",
  " DVs are fairly ordinary.",
  " DVs are rather low.",
}) do
  assert(sourceText:find(suffix, 1, true), "DV verdict suffix missing from main.lua: " .. suffix)
end

for _, message in ipairs(allSemanticMessages) do
  local boxes = fakeMod.exports.layoutAppraisalText(message)
  assert(#boxes == 1, "semantic appraisal message spilled into multiple boxes: " .. message)
  assert(not message:find("OAK:", 1, true), "appraisal verdict must not repeat speaker prefix")
  assert(not message:find("TESTMON", 1, true), "species/nickname leaked into deterministic appraisal copy")
  for _, box in ipairs(boxes) do
    local rows = 0
    for line in (box .. "\n"):gmatch("(.-)\n") do
      rows = rows + 1
      assert(visibleCells(line) <= 18, "overflow in message: " .. message .. " => " .. line)
    end
    assert(rows <= 2)
  end
end

-- DV verdicts all use "Your <PK><MN>'s ...". The native compact wordmark is
-- atomic and can never be split or hyphenated by the appraisal wrapper.
for _, idx in ipairs({1, 3, 5, 7}) do
  assert(allSemanticMessages[idx]:find("Your <PK><MN>'s DVs", 1, true) == 1)
end
local compact = fakeMod.exports.layoutAppraisalText("Your <PK><MN>'s DVs are outstanding!")
assert(compact[1]:find("<PK><MN>'s", 1, true))
for _, box in ipairs(compact) do
  assert(not box:find("<PK>\n", 1, true))
  assert(not box:find("<MN>\n", 1, true))
  assert(not box:find("<PK>-", 1, true))
  assert(not box:find("<MN>-", 1, true))
  assert(not box:find("<PK>\n<MN>", 1, true))
  assert(not box:find("<MN>\n's", 1, true))
end

-- End-to-end UI callback flow with public mod.ui facades stubbed.
local pushedScreens = {}
local stackItems = {}
local buttonHeld = true
local fakeGame = {
  save = { party = { { species = "TESTMON", nickname = "SPARKY", dvs = {attack=15, defense=15, speed=15, special=15},
                      statExp = allStatExp(65535) } } },
  data = { text = { _ClosedOaksPCText = "CLOSED OAK" } },
  input = {
    isDown = function(_, key)
      if key == "a" or key == "b" then return buttonHeld end
      return false
    end,
  },
  stack = { push = function(_, state) stackItems[#stackItems + 1] = state end },
}
fakeMod.ui.Menu = { new = function(_, items, opts) return { kind = "menu", items = items, opts = opts } end }
fakeMod.ui.TextBox = { new = function(game, text, onDone)
  return {
    kind = "text", text = text, onDone = onDone, game = game, baseUpdates = 0,
    update = function(self) self.baseUpdates = self.baseUpdates + 1 end,
  }
end }
fakeMod.ui.push = function(_, id, opts)
  pushedScreens[#pushedScreens + 1] = { id = id, opts = opts }
end

local vanillaCount = 0
local rows = capturedHook(function(_, r) return r end, fakeGame, {
  { label = "PROF.OAK's PC", keepOpen = true, onSelect = function() vanillaCount = vanillaCount + 1 end },
})
rows[1].onSelect()
local oakMenu = stackItems[#stackItems]
assert(oakMenu.kind == "menu")
assert(oakMenu.items[1].label == "SHOW POKéMON")
assert(oakMenu.items[2].label == "SHOW POKéDEX")
assert(oakMenu.items[3].label == "CANCEL")
assert(oakMenu.opts.tw == 15)

-- SHOW POKéDEX preserves the vanilla rating callback.
oakMenu.items[2].onSelect()
assert(vanillaCount == 1)

-- SHOW POKéMON is first and goes directly to PartyMenu; no terminology tutorial.
local stackBeforePokemon = #stackItems
oakMenu.items[1].onSelect()
assert(#stackItems == stackBeforePokemon)
assert(#pushedScreens == 1 and pushedScreens[1].id == "PartyMenu")
assert(pushedScreens[1].opts.forceSwitch == true)

-- The first post-selection box is the one immersive speaker/name line. It is
-- deliberately separate from the deterministic appraisal verdicts.
pushedScreens[1].opts.onSwitch(fakeGame.save.party[1])
local intro = stackItems[#stackItems]
assert(intro.kind == "text")
assert(intro.text == "OAK: Let's see...\nSPARKY!")

-- Fresh-press gate swallows the held PartyMenu A until release.
intro:update(0)
intro:update(0)
assert(intro.baseUpdates == 0)
buttonHeld = false
intro:update(0)
intro:update(0)
intro:update(0)
assert(intro.baseUpdates == 0)
intro:update(0)
assert(intro.baseUpdates == 1)

-- After the intro, the actual evaluation contains no repeated OAK: prefix and
-- uses the fixed native <PK><MN>'s glyph pair rather than the long name.
local expected = {
  "Your <PK><MN>'s DVs are\noutstanding!",
  "Its potential is\nremarkable!",
  "Its stats are\nfully developed!",
  "It reached its\nfull potential!",
}
intro.onDone()
local current = stackItems[#stackItems]
assert(current.kind == "text" and current.text == expected[1])
for i = 2, #expected do
  current.onDone()
  current = stackItems[#stackItems]
  assert(current.kind == "text")
  assert(current.text == expected[i], "unexpected appraisal box " .. i .. ": " .. tostring(current.text))
end

for _, expectedText in ipairs(expected) do
  assert(not expectedText:find("OAK:", 1, true))
  assert(not expectedText:find("TESTMON", 1, true))
  assert(not expectedText:find("SPARKY", 1, true))
  local lines = 0
  for line in (expectedText .. "\n"):gmatch("(.-)\n") do
    lines = lines + 1
    assert(visibleCells(line) <= 18)
  end
  assert(lines <= 2)
end

current.onDone()
local closeBox = stackItems[#stackItems]
assert(closeBox.text == "CLOSED OAK")

-- A later appraisal still goes directly to PartyMenu.
local stackBefore = #stackItems
local screensBefore = #pushedScreens
rows[1].onSelect()
local secondMenu = stackItems[#stackItems]
secondMenu.items[1].onSelect()
assert(#stackItems == stackBefore + 1)
assert(#pushedScreens == screensBefore + 1)
assert(pushedScreens[#pushedScreens].id == "PartyMenu")

-- B/cancel from PartyMenu reopens Oak's SHOW POKEMON / SHOW POKEDEX choice.
pushedScreens[#pushedScreens].opts.onCancel()
assert(stackItems[#stackItems].kind == "menu")
assert(stackItems[#stackItems].items[1].label == "SHOW POKéMON")


-- In-person Oak: the vanilla Oak Lab script reaches dex_rating only at its
-- normal Pokédex-rating phase. The overridden command presents the same
-- SHOW POKéMON / SHOW POKéDEX / CANCEL choice while its runner coroutine is blocked.
local function startDirectOakCommand()
  local co
  local runner = {}
  runner.yield = function() return coroutine.yield() end
  runner.resume = function()
    local ok, err = coroutine.resume(co)
    assert(ok, tostring(err))
  end
  local ctx = {
    game = fakeGame,
    overworld = { map = { id = "OAKS_LAB" } },
    runner = runner,
  }
  co = coroutine.create(function() capturedDexCommand(ctx) end)
  runner:resume()
  return co
end

-- Direct SHOW POKéDEX delegates to the captured vanilla dex_rating command.
local vanillaBeforeDirect = vanillaDexCalls
local directCo = startDirectOakCommand()
local directMenu = stackItems[#stackItems]
assert(directMenu.kind == "menu")
assert(directMenu.items[1].label == "SHOW POKéMON")
assert(directMenu.items[2].label == "SHOW POKéDEX")
assert(directMenu.items[3].label == "CANCEL")
assert(directMenu.opts.tw == 15)
directMenu.items[2].onSelect()
assert(vanillaDexCalls == vanillaBeforeDirect + 1)
assert(coroutine.status(directCo) == "dead")

-- Direct SHOW POKéMON uses the same PartyMenu and appraisal copy, but must NOT
-- append the PC-only Closed link message when the final verdict closes.
directCo = startDirectOakCommand()
directMenu = stackItems[#stackItems]
local screensBeforeDirect = #pushedScreens
directMenu.items[1].onSelect()
assert(#pushedScreens == screensBeforeDirect + 1)
local directParty = pushedScreens[#pushedScreens]
assert(directParty.id == "PartyMenu" and directParty.opts.forceSwitch == true)
directParty.opts.onSwitch(fakeGame.save.party[1])
local directIntro = stackItems[#stackItems]
assert(directIntro.kind == "text" and directIntro.text == "OAK: Let's see...\nSPARKY!")
directIntro.onDone()
local directCurrent = stackItems[#stackItems]
for i = 1, #expected do
  assert(directCurrent.kind == "text" and directCurrent.text == expected[i])
  if i < #expected then
    directCurrent.onDone()
    directCurrent = stackItems[#stackItems]
  end
end
local stackBeforeDirectFinish = #stackItems
directCurrent.onDone()
assert(#stackItems == stackBeforeDirectFinish, "in-person Oak appended an unexpected close-link TextBox")
assert(coroutine.status(directCo) == "dead")

-- B from the in-person PartyMenu returns to Oak's three-way choice rather
-- than ending or touching the PC-only path.
directCo = startDirectOakCommand()
directMenu = stackItems[#stackItems]
directMenu.items[1].onSelect()
local cancelledParty = pushedScreens[#pushedScreens]
cancelledParty.opts.onCancel()
local returnedDirectMenu = stackItems[#stackItems]
assert(returnedDirectMenu.kind == "menu")
assert(returnedDirectMenu.items[1].label == "SHOW POKéMON")
assert(returnedDirectMenu.items[2].label == "SHOW POKéDEX")
assert(returnedDirectMenu.items[3].label == "CANCEL")
returnedDirectMenu.items[3].onSelect()
assert(coroutine.status(directCo) == "dead")

print("oak_pokemon_appraisal 2.0.0: final menu ordering, appraisal layout, scoring, PC flow and in-person Oak dex-rating interception tests passed")
