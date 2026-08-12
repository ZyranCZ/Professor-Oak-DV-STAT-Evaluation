local root = (... and (...):match("^(.*)[/\\]")) or "."
local entry = assert(loadfile(root .. "/../main.lua"))()

local events = {}
local hooks = {}
local commandAccesses = 0
local eventRegistrations = {}
local hookRegistrations = {}
local fakeMod = {
  content = {
    pokemon = { get = function(_, id) return { name = id or "TESTMON" } end },
    commands = {
      get = function() commandAccesses = commandAccesses + 1; error("Gen 1 commands touched on Gold") end,
      override = function() commandAccesses = commandAccesses + 1; error("Gen 1 commands touched on Gold") end,
    },
  },
  events = { on = function(_, name, fn)
    eventRegistrations[name] = (eventRegistrations[name] or 0) + 1
    events[name] = fn
  end },
  hooks = { wrap = function(_, name, fn)
    hookRegistrations[name] = (hookRegistrations[name] or 0) + 1
    hooks[name] = fn
  end },
  ui = {},
  exports = {},
  log = { warn = function() end },
}
entry(fakeMod)
assert(type(events["game.ready"]) == "function")
assert(fakeMod.exports.version == "2.0.0")

local function newStack()
  local stack = { states = {} }
  function stack:push(state) self.states[#self.states + 1] = state; return state end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  return stack
end

local buttonHeld = false
local pushedScreens = {}
fakeMod.ui.Menu = { new = function(game, items, opts)
  return { kind = "menu", game = game, items = items, opts = opts or {} }
end }
fakeMod.ui.TextBox = { new = function(game, text, onDone)
  return {
    kind = "text", game = game, text = text, onDone = onDone, baseUpdates = 0,
    update = function(self) self.baseUpdates = self.baseUpdates + 1 end,
  }
end }
fakeMod.ui.Theme = { textBox = { maxCols = 18 } }
fakeMod.ui.Font = {
  width = function(text)
    text = tostring(text or "")
    local n, i = 0, 1
    while i <= #text do
      if text:sub(i, i + 3) == "<PK>" or text:sub(i, i + 3) == "<MN>" then i = i + 4
      elseif text:sub(i, i + 1) == "'s" then i = i + 2
      else i = i + 1 end
      n = n + 1
    end
    return n * 8
  end,
  split = function(text)
    local spans, i = {}, 1
    while i <= #text do
      local len = 1
      if text:sub(i, i + 3) == "<PK>" or text:sub(i, i + 3) == "<MN>" then len = 4
      elseif text:sub(i, i + 1) == "'s" then len = 2 end
      spans[#spans + 1] = { from = i, to = i + len - 1 }
      i = i + len
    end
    return spans
  end,
}
fakeMod.ui.push = function(game, id, opts)
  local state = { kind = "screen", id = id, opts = opts, game = game }
  pushedScreens[#pushedScreens + 1] = state
  game.stack:push(state)
  return state
end

local goldGame = {
  data = {
    gen2Maps = {
      GOLDENROD_HAPPINESS_RATER = {
        id = "GOLDENROD_HAPPINESS_RATER",
        objects = {
          { scriptKey = "2a:4567" },
          { scriptKey = "2a:9999" },
          { scriptKey = "2a:aaaa" },
        },
      },
      ELMS_LAB = {
        id = "ELMS_LAB",
        objects = {
          { scriptKey = "24:1111" }, -- ELMSLAB_ELM / ProfElmScript
          { scriptKey = "24:aide" },
        },
      },
    },
    gen2Scripts = {
      -- Structural fixture mirroring ProfElmScript's relevant control-flow.
      -- The mod resolves these keys without relying on ROM addresses or text.
      ["24:1111"] = {
        { op="faceplayer" }, { op="opentext" },
        { op="checkflag" }, { op="iftrue", script="elm:masterball" },
        { op="checkevent" }, { op="iftrue", script="elm:call" },
        { op="checkevent" }, { op="iftrue", script="elm:everstone" },
        { op="checkevent" }, { op="iffalse", script="elm:eggcheck" },
        { op="end" },
      },
      ["elm:eggcheck"] = {
        { op="checkevent" }, { op="iffalse", script="elm:goteggagain" },
        { op="end" },
      },
      ["elm:goteggagain"] = {
        { op="checkevent" }, { op="iftrue", script="elm:waiting" },
        { op="checkflag" },  { op="iftrue", script="elm:aidehasegg" },
        { op="checkevent" }, { op="iftrue", script="elm:studying" },
        { op="checkevent" }, { op="iftrue", script="elm:aftertheft" },
        { op="checkevent" }, { op="iftrue", script="elm:describes" },
        { op="writetext" }, { op="waitbutton" }, { op="closetext" }, { op="end" },
      },
      ["elm:waiting"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:aidehasegg"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:studying"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:aftertheft"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:describes"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:call"] = { {op="writetext"}, {op="waitbutton"}, {op="closetext"}, {op="end"} },
      ["elm:masterball"] = { {op="end"} },
      ["elm:everstone"] = { {op="end"} },
    },
  },
  save = { party = {} },
  input = {
    isDown = function(_, key)
      return buttonHeld and (key == "a" or key == "b")
    end,
  },
  stack = newStack(),
}

events["game.ready"]({ game = goldGame })
assert(commandAccesses == 0, "Gold boot touched Gen 1 dex_rating registry")
assert(hooks["ui.pc.items"] == nil, "Gen 1 PC hook installed on Gold")
assert(type(hooks["script.command"]) == "function", "Gold script.command hook missing")
assert(type(events["screen.pushed"]) == "function", "Gold screen.pushed listener missing")
assert(type(events["script.started"]) == "function", "Gold script.started listener missing")
assert(type(events["script.ended"]) == "function", "Gold script.ended listener missing")
local diag = fakeMod.exports.diagnostics()
assert(diag.generation == 2 and diag.backend == "gold")
assert(diag.happinessScriptKeyResolved == true)
assert(diag.personalAppraisalInstalled == true)
assert(diag.elmScriptKeyResolved == true)
assert(diag.elmAppraisalInstalled == true)
assert(diag.elmIdleScriptCount == 0, "obsolete Elm idle-branch resolver is still active")

-- Re-emitted game.ready (the same beat used by dev hot reload) must not stack
-- this closure's Gold listeners/wrappers.  Per-screen decoration has its own
-- idempotence assertion below.
local eventCountsAfterInstall = {}
for name, count in pairs(eventRegistrations) do eventCountsAfterInstall[name] = count end
local hookCountsAfterInstall = {}
for name, count in pairs(hookRegistrations) do hookCountsAfterInstall[name] = count end
events["game.ready"]({ game = goldGame })
for name, count in pairs(eventCountsAfterInstall) do
  assert(eventRegistrations[name] == count, "duplicate Gold event registration on repeated game.ready: " .. name)
end
for name, count in pairs(hookCountsAfterInstall) do
  assert(hookRegistrations[name] == count, "duplicate Gold hook registration on repeated game.ready: " .. name)
end

-- Scoring parity: Gold remains four stored DVs and five Stat Experience buckets.
local function mon(dvs, statExp, extra)
  local m = { dvs = dvs or {}, statExp = statExp or {} }
  if extra then for k, v in pairs(extra) do m[k] = v end end
  return m
end
local dv = fakeMod.exports.scoreDVs(mon({ attack=15, defense=15, speed=15, special=15, hp=15 }))
assert(dv.sum == 60 and dv.max == 60 and dv.tier == "outstanding")
assert(fakeMod.exports.scoreDVs(mon({attack=15, defense=15, speed=10, special=10})).sum == 50)
assert(fakeMod.exports.scoreDVs(mon({attack=15, defense=15, speed=10, special=9})).tier == "above_average")
assert(fakeMod.exports.scoreDVs(mon({attack=10, defense=10, speed=10, special=10})).tier == "above_average")
assert(fakeMod.exports.scoreDVs(mon({attack=8, defense=8, speed=8, special=7})).tier == "ordinary")
assert(fakeMod.exports.scoreDVs(mon({attack=8, defense=8, speed=7, special=7})).tier == "limited")
local specialOnly = fakeMod.exports.scoreTrainingGold(mon({}, { hp=0, attack=0, defense=0, speed=0, special=65535 }))
assert(specialOnly.sum == 63 and specialOnly.max == 315, "Gold Special Stat Exp was double-counted")
for _, value in ipairs({0, 1, 16, 4096, 16384, 40000, 63001, 63002, 65535}) do
  local expected = math.floor(math.sqrt(value) / 4)
  assert(fakeMod.exports.effectiveStatExpGold(value) == expected,
    "Gold Stat Exp parity failed at " .. value)
end
assert(fakeMod.exports.effectiveStatExp(63002) == 63,
  "Gen 1 v1.0.2 Stat Exp semantics changed during Gold port")
assert(fakeMod.exports.effectiveStatExpGold(63002) == 62,
  "Gold Mon.lua boundary mismatch at 63002")

-- Cross-feature scoring invariants: native Gold Sp. Atk/Sp. Def display fields,
-- held items, happiness, gender, shiny/Pokerus/form/records are not extra score
-- buckets.  Only the four stored DVs and five Stat Exp buckets are authoritative.
local crossFeatureMon = mon(
  {attack=10, defense=10, speed=10, special=10, hp=15},
  {hp=16384, attack=16384, defense=16384, speed=16384, special=16384,
   specialAttack=65535, specialDefense=65535},
  {specialAttack=999, specialDefense=1, item="THICK_CLUB", happiness=255,
   gender="female", shiny=true, pokerus=15, form="B", level=100,
   records={battles=999, criticalHits=123}})
local crossDv = fakeMod.exports.scoreDVs(crossFeatureMon)
local crossTraining = fakeMod.exports.scoreTrainingGold(crossFeatureMon)
assert(crossDv.sum == 40 and crossDv.max == 60,
  "Gold score read derived HP DV or an unrelated cross-feature field")
assert(crossTraining.sum == 160 and crossTraining.max == 315,
  "Gold score double-counted SpA/SpD or another unrelated field")

local function selectMenu(menu, index)
  assert(goldGame.stack:top() == menu)
  goldGame.stack:pop() -- production Menu pops itself before onSelect
  local item = assert(menu.items[index])
  if item.onSelect then item.onSelect() end
end
local function cancelMenu(menu)
  assert(goldGame.stack:top() == menu)
  goldGame.stack:pop()
  if menu.opts.onCancel then menu.opts.onCancel() end
end
local function dismissText(box)
  assert(box and box.kind == "text")
  if goldGame.stack:top() == box then goldGame.stack:pop() end
  if box.onDone then box.onDone() end
end
local function finishAppraisal()
  local seen = {}
  for _ = 1, 5 do
    local box = goldGame.stack:top()
    assert(box and box.kind == "text", "expected appraisal TextBox")
    seen[#seen + 1] = box.text
    dismissText(box)
  end
  return seen
end

-- Gold CenterPcMenu: native gate is respected because the mod never inserts rows.
local nativeNoDex = 0
local beforeDex = {
  screenId = "Gen2CenterPcMenu", game = goldGame,
  entries = { {id="bills"}, {id="players"}, {id="turnoff"} }, index = 1,
  choose = function() nativeNoDex = nativeNoDex + 1 end,
  oakClosed = function() error("Oak close must not run before Dex") end,
}
events["screen.pushed"]({ state = beforeDex })
beforeDex:choose()
assert(nativeNoDex == 1)
assert(#beforeDex.entries == 3, "mod manufactured PROF.OAK's PC before Pokédex")

-- After Dex, only the existing native `oaks` row is decorated.
local nativeOakChoose = 0
local nativeChoices = {}
local oakClosed = 0
local center = {
  screenId = "Gen2CenterPcMenu", game = goldGame,
  entries = { {id="bills"}, {id="players"}, {id="oaks"}, {id="hof"}, {id="turnoff"} },
  index = 3,
  choose = function(self)
    nativeOakChoose = nativeOakChoose + 1
    nativeChoices[#nativeChoices + 1] = self.entries[self.index].id
  end,
  oakClosed = function() oakClosed = oakClosed + 1 end,
}
events["screen.pushed"]({ state = center })
local wrappedChoose = center.choose
events["screen.pushed"]({ state = center })
assert(center.choose == wrappedChoose, "CenterPcMenu wrapper stacked twice")
center:choose()
local oakMenu = goldGame.stack:top()
assert(oakMenu.kind == "menu")
assert(oakMenu.items[1].label == "SHOW POKéMON")
assert(oakMenu.items[2].label == "SHOW POKéDEX")
assert(oakMenu.items[3].label == "CANCEL")

-- SHOW POKéDEX delegates to the captured native choose exactly once.
selectMenu(oakMenu, 2)
assert(nativeOakChoose == 1)
assert(nativeChoices[1] == "oaks", "SHOW POKéDEX did not delegate the native Oak row")

-- Bill/Player/Hall-of-Fame rows remain native.
for _, idx in ipairs({1, 2, 4, 5}) do
  center.index = idx
  center:choose()
end
assert(nativeOakChoose == 5)
assert(table.concat(nativeChoices, ",") == "oaks,bills,players,hof,turnoff",
  "non-Oak Center PC rows were not delegated unchanged")
center.index = 3

-- SHOW POKéMON uses direct Gen2PartyMenu; selection does not reorder/mutate party.
local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for k, v in pairs(value) do out[deepCopy(k, seen)] = deepCopy(v, seen) end
  return out
end
local function deepEqual(a, b, seen)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for k, v in pairs(a) do if not deepEqual(v, b[k], seen) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local selected = {
  species = "PIKACHU", nickname = "SPARKY",
  dvs = {attack=15, defense=15, speed=15, special=15},
  statExp = {hp=65535, attack=65535, defense=65535, speed=65535, special=65535},
  hp = 20, happiness = 200, item = "BERRY", status = "par",
  level = 100, gender = "female", shiny = true, pokerus = 7, form = "A",
  moves = {"THUNDERBOLT", "QUICK_ATTACK", "GROWL", "THUNDER_WAVE"},
  ot = { name = "GOLD", id = 12345 },
  records = { battles = 428, victories = 401 },
  specialAttack = 123, specialDefense = 117,
}
goldGame.save.party = { selected }
center:choose()
oakMenu = goldGame.stack:top()
selectMenu(oakMenu, 1)
local partyScreen = goldGame.stack:top()
assert(partyScreen.id == "Gen2PartyMenu")
assert(partyScreen.opts.submenu == nil and partyScreen.opts.prompt == "choose")
local partyIdentityBefore = goldGame.save.party[1]
local before = deepCopy(selected)
partyScreen.opts.onChoose(1, selected)
local intro = goldGame.stack:top()
assert(intro.text == "OAK: Let's see...\nSPARKY!")

-- Same fresh-press guard is active on Gold-owned appraisal boxes.
buttonHeld = true
intro:update(0); intro:update(0)
assert(intro.baseUpdates == 0)
buttonHeld = false
intro:update(0); intro:update(0); intro:update(0)
assert(intro.baseUpdates == 0)
intro:update(0)
assert(intro.baseUpdates == 1)

local oakTexts = finishAppraisal()
assert(oakClosed == 1, "Gold Oak appraisal did not use native oakClosed")
assert(goldGame.save.party[1] == partyIdentityBefore,
  "Gold appraisal replaced/reordered the selected party object")
assert(deepEqual(selected, before),
  "Gold appraisal mutated a selected-mon field (including item/status/moves/OT/gender/shiny/Pokerus/records)")
for _, text in ipairs(oakTexts) do
  assert(not text:find("SPARKY", 1, true) or text:find("OAK: Let's see", 1, true))
end

-- Fainted/statused/Lv100 Pokemon remain legal appraisal targets.  Appraisal is
-- about DVs + current Stat Exp, not battle readiness or level.
local fainted = deepCopy(selected)
fainted.nickname, fainted.hp, fainted.status, fainted.level = "FAINTED", 0, "slp", 100
local faintedBefore = deepCopy(fainted)
goldGame.save.party = { fainted }
center:choose(); oakMenu = goldGame.stack:top(); selectMenu(oakMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(1, fainted)
assert(goldGame.stack:top().text == "OAK: Let's see...\nFAINTED!")
finishAppraisal()
assert(deepEqual(fainted, faintedBefore), "fainted Pokemon appraisal unexpectedly mutated state")

-- Form metadata (notably Unown-style forms) is presentation/state, not quality.
-- A non-nicknamed form can still be appraised and the form field stays untouched.
local unown = {
  species="UNOWN", form="B", level=23, gender="genderless", shiny=false,
  dvs={attack=8, defense=9, speed=10, special=11},
  statExp={hp=40000, attack=100, defense=200, speed=300, special=400},
  hp=1, item=nil, happiness=70, status=nil,
}
local companion = deepCopy(selected); companion.nickname = "SECOND"
local unownBefore = deepCopy(unown)
goldGame.save.party = { companion, unown }
center:choose(); oakMenu = goldGame.stack:top(); selectMenu(oakMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(2, unown)
assert(goldGame.stack:top().text == "OAK: Let's see...\nUNOWN!")
finishAppraisal()
assert(goldGame.save.party[1] == companion and goldGame.save.party[2] == unown,
  "Gold appraisal reordered a multi-Pokemon party")
assert(deepEqual(unown, unownBefore) and unown.form == "B",
  "Gold appraisal mutated Unown/form metadata")

-- Party B returns to the custom Oak choice.
center:choose(); oakMenu = goldGame.stack:top(); selectMenu(oakMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onCancel()
assert(goldGame.stack:top().items[1].label == "SHOW POKéMON")
cancelMenu(goldGame.stack:top())

-- Egg selection refuses safely, leaks no hidden species, then reopens picker.
local egg = { isEgg = true, species = "TOGEPI", dvs = {attack=15}, statExp = {special=65535} }
goldGame.save.party = { egg, selected }
center:choose(); oakMenu = goldGame.stack:top(); selectMenu(oakMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(1, egg)
local refusal = goldGame.stack:top()
assert(refusal.kind == "text" and refusal.text:find("EGG", 1, true))
assert(not refusal.text:find("TOGEPI", 1, true))
dismissText(refusal)
assert(goldGame.stack:top().id == "Gen2PartyMenu")
goldGame.stack:top().opts.onCancel()
cancelMenu(goldGame.stack:top())

-- -------------------------------------------------------------------------
-- Goldenrod Happiness Rater exact provenance + coroutine behavior.

local scriptHook = hooks["script.command"]
local nextCalls = 0
local function nativeNext(_, _, _, _)
  nextCalls = nextCalls + 1
  return nil
end
local function makeVm()
  local holder = { co = nil, callbackResumes = 0 }
  local vm = {}
  function vm:specialName(id) return id == 77 and "GetFirstPokemonHappiness" or "OtherSpecial" end
  function vm:resume()
    holder.callbackResumes = holder.callbackResumes + 1
    local ok, err = coroutine.resume(holder.co)
    assert(ok, tostring(err))
  end
  return vm, holder
end
local function startRater(ctxOverrides, nextFn)
  local vm, holder = makeVm()
  local ctx = {
    generation = 2, scriptKey = "2a:4567", kind = "object",
    mapId = "GOLDENROD_HAPPINESS_RATER", mapGroup = 11, mapNumber = 5,
    object = 1, vm = vm,
  }
  for k, v in pairs(ctxOverrides or {}) do ctx[k] = v end
  local result
  holder.co = coroutine.create(function()
    -- Production Hooks:call executes each wrapper under pcall.  Exercise the
    -- same protected boundary while this custom command parks/resumes the VM.
    local protected = { pcall(scriptHook, nextFn or nativeNext, ctx, "special", {77},
      { special = 77 }) }
    assert(protected[1], tostring(protected[2]))
    result = protected[2]
  end)
  local ok, err = coroutine.resume(holder.co)
  assert(ok, tostring(err))
  return ctx, holder, function() return result end
end

-- Same special elsewhere must chain untouched and never open the custom menu.
local wrongVm = { specialName = function() return "GetFirstPokemonHappiness" end }
local wrongCtx = { generation=2, scriptKey="2a:4567", mapId="OTHER_MAP",
  mapGroup=11, mapNumber=5, object=1, vm=wrongVm }
local stackBefore = #goldGame.stack.states
scriptHook(nativeNext, wrongCtx, "special", {77}, {special=77})
assert(nextCalls == 1 and #goldGame.stack.states == stackBefore)

-- CHECK HAPPINESS: native special runs exactly once; following vanilla script remains intact.
local _, holder, result = startRater()
local raterMenu = goldGame.stack:top()
assert(raterMenu.items[1].label == "CHECK HAPPINESS")
assert(raterMenu.items[2].label == "APPRAISE")
assert(raterMenu.items[3].label == "CANCEL")
selectMenu(raterMenu, 1)
assert(coroutine.status(holder.co) == "dead")
assert(nextCalls == 2, "CHECK HAPPINESS did not call native special exactly once")
assert(holder.callbackResumes == 1)
assert(result() == nil)

-- CHECK HAPPINESS is a transparent delegation point.  Exercise all six native
-- Gold tier outcomes through the wrapper: the mod must return the native
-- result unchanged and invoke the native special exactly once per talk.
local function vanillaHappinessTier(party)
  local target
  for _, candidate in ipairs(party or {}) do
    if not candidate.isEgg then target = candidate; break end
  end
  if not target then return "NO_MON" end
  local h = target.happiness or 0
  if h >= 250 then return "250+" end
  if h >= 200 then return "200+" end
  if h >= 150 then return "150+" end
  if h >= 100 then return "100+" end
  if h >= 50 then return "50+" end
  return "<50"
end
for _, case in ipairs({
  {255, "250+"}, {200, "200+"}, {150, "150+"},
  {100, "100+"}, {50, "50+"}, {49, "<50"},
}) do
  local tierMon = deepCopy(selected); tierMon.happiness = case[1]
  goldGame.save.party = { tierMon }
  local calls = 0
  local function nativeTierNext()
    calls = calls + 1
    return vanillaHappinessTier(goldGame.save.party)
  end
  local _, tierHolder, tierResult = startRater(nil, nativeTierNext)
  local tierMenu = goldGame.stack:top(); selectMenu(tierMenu, 1)
  assert(coroutine.status(tierHolder.co) == "dead")
  assert(calls == 1 and tierResult() == case[2],
    "CHECK HAPPINESS changed native tier delegation at happiness " .. case[1])
end

-- Native first-non-Egg semantics also pass through untouched.
local eggForHappiness = { isEgg=true, happiness=255, species="TOGEPI" }
local nonEggForHappiness = deepCopy(selected); nonEggForHappiness.happiness = 200
goldGame.save.party = { eggForHappiness, nonEggForHappiness }
local eggSkipCalls = 0
local function nativeEggSkip()
  eggSkipCalls = eggSkipCalls + 1
  return vanillaHappinessTier(goldGame.save.party)
end
local _, skipHolder, skipResult = startRater(nil, nativeEggSkip)
local skipMenu = goldGame.stack:top(); selectMenu(skipMenu, 1)
assert(coroutine.status(skipHolder.co) == "dead")
assert(eggSkipCalls == 1 and skipResult() == "200+",
  "CHECK HAPPINESS stopped delegating native first-non-Egg behavior")

-- APPRAISE can select any non-Egg party mon, uses Rater intro, then returns "end"
-- so the vanilla happiness text/threshold branch does not run afterwards.
goldGame.save.party = { egg, selected }
local nextBeforeAppraise = nextCalls
local _, appHolder, appResult = startRater()
raterMenu = goldGame.stack:top(); selectMenu(raterMenu, 2)
partyScreen = goldGame.stack:top(); assert(partyScreen.id == "Gen2PartyMenu")
partyScreen.opts.onChoose(2, selected)
intro = goldGame.stack:top()
assert(intro.text == "Oh? Let me see\nyour SPARKY...")
-- Autofire/touch-style intermittent held edges cannot satisfy the neutral gate.
-- Three consecutive released frames are required before the shared TextBox sees input.
buttonHeld = true; intro:update(0)
buttonHeld = false; intro:update(0); intro:update(0)
buttonHeld = true; intro:update(0)
buttonHeld = false; intro:update(0); intro:update(0)
assert(intro.baseUpdates == 0, "intermittent autofire edges bypassed fresh-press neutral gate")
intro:update(0); assert(intro.baseUpdates == 0)
intro:update(0); assert(intro.baseUpdates == 1)
local raterTexts = finishAppraisal()
assert(coroutine.status(appHolder.co) == "dead")
assert(appResult() == "end")
assert(nextCalls == nextBeforeAppraise, "APPRAISE fell through into native happiness branch")
assert(appHolder.callbackResumes == 3, "APPRAISE VM resume count changed")
for _, text in ipairs(raterTexts) do
  if text ~= "Oh? Let me see\nyour SPARKY..." then
    assert(not text:find("RATER:", 1, true))
  end
end

-- Max legal Gold nickname keeps the Rater intro within the 18-cell line budget.
local longName = {
  species="PIKACHU", nickname="ABCDEFGHIJ",
  dvs=selected.dvs, statExp=selected.statExp,
}
goldGame.save.party = { longName }
local _, longHolder = startRater()
raterMenu = goldGame.stack:top(); selectMenu(raterMenu, 2)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(1, longName)
intro = goldGame.stack:top()
assert(intro.text == "Oh? Let me see\nyour ABCDEFGHIJ...")
local secondLine = intro.text:match("\n(.+)$")
assert(#secondLine == 18)
finishAppraisal()
assert(coroutine.status(longHolder.co) == "dead")

-- Egg: refusal contains no species/DVs; after dismissal the picker reopens.
goldGame.save.party = { egg, selected }
local _, eggHolder, eggResult = startRater()
raterMenu = goldGame.stack:top(); selectMenu(raterMenu, 2)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(1, egg)
refusal = goldGame.stack:top()
assert(refusal.text == "An EGG can't be\nappraised yet.")
assert(not refusal.text:find("TOGEPI", 1, true))
dismissText(refusal)
partyScreen = goldGame.stack:top(); assert(partyScreen.id == "Gen2PartyMenu")
partyScreen.opts.onCancel()
raterMenu = goldGame.stack:top()
assert(raterMenu.items[1].label == "CHECK HAPPINESS")
selectMenu(raterMenu, 3)
assert(coroutine.status(eggHolder.co) == "dead" and eggResult() == "end")

-- Root B/CANCEL ends cleanly without invoking native happiness.
local nextBeforeCancel = nextCalls
local _, cancelHolder, cancelResult = startRater()
raterMenu = goldGame.stack:top(); cancelMenu(raterMenu)
assert(coroutine.status(cancelHolder.co) == "dead")
assert(cancelResult() == "end" and nextCalls == nextBeforeCancel)

-- Repeated conversation gets fresh state; no stale previous choice survives.
local _, repeatHolder = startRater()
raterMenu = goldGame.stack:top(); selectMenu(raterMenu, 1)
assert(coroutine.status(repeatHolder.co) == "dead")

-- -------------------------------------------------------------------------
-- Professor Elm: the vanilla run is only OBSERVED.  The command hook must be
-- a pure pass-through; the supplemental menu is appended after script.ended.
-- RC.5 deliberately does not require the imported ProfElmScript key.

local function elmCtx(overrides)
  local ctx = {
    generation = 2, scriptKey = "runtime:can-differ", kind = "script",
    mapId = "ELMS_LAB", mapGroup = 24, mapNumber = 5,
    object = 1, vm = {},
  }
  if overrides then for k, v in pairs(overrides) do ctx[k] = v end end
  return ctx
end

local elmNativeCalls = 0
local function nativeElmCommand(_, _, _, _)
  elmNativeCalls = elmNativeCalls + 1
  return "native-result"
end

local function startElmObservation(ctx)
  events["script.started"]({ ctx = ctx })
  local before = #goldGame.stack.states
  local result = scriptHook(nativeElmCommand, ctx,
    "faceplayer", {}, { op="faceplayer" })
  assert(result == "native-result", "Elm faceplayer command was not passed through")
  assert(#goldGame.stack.states == before,
    "Elm appraisal appeared while vanilla ProfElmScript was still running")
  -- A later story/text command remains native too; marking the conversation
  -- must not alter return values, command order or UI.
  result = scriptHook(nativeElmCommand, ctx,
    "writetext", {1, 2}, { op="writetext", text="ElmStoryText" })
  assert(result == "native-result")
  assert(#goldGame.stack.states == before)
  return before
end

-- Before obtaining a starter, even a fully observed + completed Elm talk does
-- not manufacture the supplemental menu because the party is still empty.
goldGame.save.party = {}
local ctx = elmCtx()
local stackBeforeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
assert(#goldGame.stack.states == stackBeforeElm,
  "Elm appraisal appeared before the player had a Pokemon")

-- Live-failure regression: a DIFFERENT scriptKey must not suppress Elm.  The
-- canonical map + Elm object + observed vanilla faceplayer beat is sufficient.
goldGame.save.party = { selected }
ctx = elmCtx({ scriptKey = "different-from-map-object-cache" })
local beforeNativeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
local elmMenu = goldGame.stack:top()
assert(elmMenu and elmMenu.kind == "menu")
assert(elmMenu.items[1].label == "APPRAISE")
assert(elmMenu.items[2].label == "CANCEL")
local elmDiag = fakeMod.exports.diagnostics()
assert(elmDiag.lastContext.special == "ProfessorElmPostDialogue")
assert(elmDiag.elmCommandSeen >= 1 and elmDiag.elmCompletedSeen >= 1)
selectMenu(elmMenu, 2)
assert(#goldGame.stack.states == beforeNativeElm)

-- Either map identity representation is accepted.  Some runtime paths provide
-- the friendly id, others expose only cartridge group/number.
ctx = elmCtx({ mapGroup = false, mapNumber = false, scriptKey = "anything" })
startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
elmMenu = goldGame.stack:top(); assert(elmMenu.items[1].label == "APPRAISE")
selectMenu(elmMenu, 2)
ctx = elmCtx({ mapId = false, scriptKey = "anything-else" })
startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
elmMenu = goldGame.stack:top(); assert(elmMenu.items[1].label == "APPRAISE")
selectMenu(elmMenu, 2)

-- APPRAISE opens direct Gen2PartyMenu and uses Elm's speaker copy.  Completion
-- returns to the overworld, never to Oak-PC close text.
ctx = elmCtx({ scriptKey = "live-pointer-not-required" })
beforeNativeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
elmMenu = goldGame.stack:top(); selectMenu(elmMenu, 1)
partyScreen = goldGame.stack:top(); assert(partyScreen.id == "Gen2PartyMenu")
partyScreen.opts.onChoose(1, selected)
intro = goldGame.stack:top()
assert(intro.text == "ELM: Let's see...\nSPARKY!", "Elm appraisal used the wrong speaker intro")
local elmTexts = finishAppraisal()
assert(#goldGame.stack.states == beforeNativeElm,
  "Elm appraisal did not return cleanly to the overworld")
for _, text in ipairs(elmTexts) do
  assert(not text:find("OAK:", 1, true), "Elm appraisal leaked Oak speaker text")
  assert(not text:find("Closed link to", 1, true), "Elm appraisal leaked Oak PC close text")
end

-- Party B returns to our supplemental menu only; the completed VM is never
-- resumed or re-entered.
ctx = elmCtx()
beforeNativeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
elmMenu = goldGame.stack:top(); selectMenu(elmMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onCancel()
elmMenu = goldGame.stack:top(); assert(elmMenu.items[1].label == "APPRAISE")
selectMenu(elmMenu, 2)
assert(#goldGame.stack.states == beforeNativeElm)

-- Egg remains opaque and reopens only the party picker.
goldGame.save.party = { egg, selected }
ctx = elmCtx()
beforeNativeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = true })
elmMenu = goldGame.stack:top(); selectMenu(elmMenu, 1)
partyScreen = goldGame.stack:top(); partyScreen.opts.onChoose(1, egg)
refusal = goldGame.stack:top()
assert(refusal.text == "An EGG can't be\nappraised yet.")
assert(not refusal.text:find("TOGEPI", 1, true))
dismissText(refusal)
partyScreen = goldGame.stack:top(); assert(partyScreen.id == "Gen2PartyMenu")
partyScreen.opts.onCancel(); elmMenu = goldGame.stack:top(); selectMenu(elmMenu, 2)
assert(#goldGame.stack.states == beforeNativeElm)

-- Safety: script.ended alone is not enough.  This prevents stale hLastTalked
-- from making a bookshelf/sign in Elm's Lab look like Elm after object 1 was
-- previously spoken to.
goldGame.save.party = { selected }
local function assertNoElmMenuWithoutArm(endCtx, completed)
  local before = #goldGame.stack.states
  events["script.started"]({ ctx = endCtx })
  events["script.ended"]({ ctx = endCtx, completed = completed })
  assert(#goldGame.stack.states == before)
end
assertNoElmMenuWithoutArm(elmCtx(), true)
assertNoElmMenuWithoutArm(elmCtx({ object = 2 }), true)
assertNoElmMenuWithoutArm(elmCtx({ mapId="NEW_BARK_TOWN", mapGroup=24, mapNumber=4 }), true)

-- Aborted Elm conversation: even after seeing Elm's faceplayer, completed=false
-- must clear the marker without showing UI or leaking into the next script.
ctx = elmCtx()
beforeNativeElm = startElmObservation(ctx)
events["script.ended"]({ ctx = ctx, completed = false })
assert(#goldGame.stack.states == beforeNativeElm)
assertNoElmMenuWithoutArm(elmCtx(), true)

-- Different VM/run cannot consume a marker from an earlier Elm run.
ctx = elmCtx({ vm = {} })
beforeNativeElm = startElmObservation(ctx)
local otherCtx = elmCtx({ vm = {} })
events["script.ended"]({ ctx = otherCtx, completed = true })
assert(#goldGame.stack.states == beforeNativeElm)

assert(elmNativeCalls >= 10, "Elm pass-through coverage did not execute")

print("oak_pokemon_appraisal 2.0.0 Gold headless: scoring/read-only cross-feature invariants, CenterPcMenu, fresh-press, Happiness Rater tiers/VM, and Professor Elm post-dialogue priority flows passed")
