-- PROFESSOR OAK'S POKEMON APPRAISAL v2.0.1
-- Target validated against Gen1Recomp v0.1.86 / Mod API 2; no version pin
--
-- Preserves the Red/Blue/Yellow Oak appraisal flow and adds Pokémon Gold routes
-- through native PROF.OAK's PC, Goldenrod's Happiness Rater, and a post-dialogue
-- Professor Elm supplement. Appraisal is read-only and scores stored DVs plus
-- battle-grown Stat Experience with generation-correct arithmetic.

local MOD_VERSION = "2.0.1"
local MAX_DV_SUM = 60
local MAX_EFFECTIVE_STAT_EXP_PER_STAT = 63
local STAT_EXP_KEYS = { "hp", "attack", "defense", "speed", "special" }
local MAX_TRAINING_SUM = MAX_EFFECTIVE_STAT_EXP_PER_STAT * #STAT_EXP_KEYS
local PKMN_POSSESSIVE = "<PK><MN>'s"

local function clampNumber(value, lo, hi)
  value = tonumber(value) or 0
  if value < lo then return lo end
  if value > hi then return hi end
  return value
end

-- Mirrors Gen1Recomp v0.1.86 Stats.calc's Stat Experience contribution:
-- floor(min(255, ceil(sqrt(statExp))) / 4), i.e. 0..63 per stat.
-- This measures effective training potential rather than raw 0..65535 storage.
local function effectiveStatExp(statExp)
  local value = clampNumber(statExp, 0, 65535)
  return math.floor(math.min(255, math.ceil(math.sqrt(value))) / 4)
end

-- Gold's current Mon.lua uses floor(sqrt(statExp) / 4), not the historical
-- Gen 1 ceil-sqrt expression above.  Keep Gen 1 v1.0.2 byte-for-byte in its
-- scoring semantics while making Gold appraisal agree with the engine that
-- actually calculates its stats.
local function effectiveStatExpGold(statExp)
  local value = clampNumber(statExp, 0, 65535)
  return math.floor(math.sqrt(value) / 4)
end

local function dvScore(mon)
  local dvs = (type(mon) == "table" and mon.dvs) or {}
  local sum = clampNumber(dvs.attack, 0, 15)
            + clampNumber(dvs.defense, 0, 15)
            + clampNumber(dvs.speed, 0, 15)
            + clampNumber(dvs.special, 0, 15)
  return sum, (sum / MAX_DV_SUM) * 100
end

local function trainingScore(mon, effectiveFn)
  local statExp = (type(mon) == "table" and mon.statExp) or {}
  local sum = 0
  effectiveFn = effectiveFn or effectiveStatExp
  for _, key in ipairs(STAT_EXP_KEYS) do
    sum = sum + effectiveFn(statExp[key])
  end
  return sum, (sum / MAX_TRAINING_SUM) * 100
end

local function dvTier(sum)
  if sum >= 50 then return "outstanding" end
  if sum >= 40 then return "above_average" end
  if sum >= 31 then return "ordinary" end
  return "limited"
end

local function trainingTier(percent)
  if percent >= 100 then return "complete" end
  if percent > 70 then return "nearly_complete" end
  if percent > 40 then return "well_trained" end
  if percent > 20 then return "developing" end
  return "starting"
end

local function copyItem(item)
  local out = {}
  for k, v in pairs(item or {}) do out[k] = v end
  return out
end

return function(mod)
  -- Every appraisal TextBox must require a fresh button press.  A box can be
  -- pushed from inside the callback that consumed the previous A press (PC
  -- choice, PartyMenu selection, or the previous TextBox).  Gen1Recomp's
  -- TextBox correctly uses edge-triggered input, but holding/repeating A can
  -- otherwise make a newly pushed box feel as though it "runs away".
  --
  -- Keep the new box inert until A/B have both been released for a few
  -- consecutive frames.  Only after that neutral gate has completed do we
  -- hand control to the normal public TextBox implementation.  This changes
  -- no global input behavior and applies only to this mod's own dialogue.
  local NEUTRAL_FRAMES_REQUIRED = 3

  local function requireFreshPress(box)
    if type(box) ~= "table" or type(box.update) ~= "function" then
      return box
    end

    local baseUpdate = box.update
    local started = false
    local checkpointKey = nil
    local checkpointArmed = false
    local neutralFrames = 0

    local function currentCheckpoint(self)
      if not started then return "start" end
      if self.done then return "done" end
      if self.waiting then
        return table.concat({
          "wait", tostring(self.pageIndex or 0), tostring(self.lineIndex or 0),
          tostring(self.contAdvance and 1 or 0),
        }, ":")
      end
      return nil
    end

    box.update = function(self, dt)
      local input = self.game and self.game.input
      local key = currentCheckpoint(self)

      if key ~= checkpointKey then
        checkpointKey = key
        checkpointArmed = false
        neutralFrames = 0
      end

      -- At the start of the box, at every explicit page/CONT wait, and at
      -- the final close prompt, require a neutral A/B release before normal
      -- TextBox input may see another press.  This makes every visible
      -- advance a deliberate new click rather than a carried/held one.
      if key and not checkpointArmed
          and input and type(input.isDown) == "function" then
        if input:isDown("a") or input:isDown("b") then
          neutralFrames = 0
        else
          neutralFrames = neutralFrames + 1
        end
        if neutralFrames >= NEUTRAL_FRAMES_REQUIRED then
          checkpointArmed = true
          if key == "start" then started = true end
        end
        return
      end

      return baseUpdate(self, dt)
    end
    return box
  end

  local function pushText(game, text, onDone)
    local box = mod.ui.TextBox.new(game, text, onDone)
    game.stack:push(requireFreshPress(box))
  end

  -- The one immersive speaker-identification box uses the selected Pokemon's
  -- actual display name. All appraisal verdicts that follow use the compact
  -- native <PK><MN>'s glyph pair so their layout is species-independent.
  local function pokemonName(mon)
    if type(mon) ~= "table" then return "POKéMON" end
    if type(mon.nickname) == "string" and mon.nickname ~= "" then
      return mon.nickname
    end
    local def = mon.species and mod.content and mod.content.pokemon
      and mod.content.pokemon:get(mon.species)
    return (def and def.name) or mon.species or "POKéMON"
  end

  local function oakIntro(mon)
    return "OAK: Let's see...\n" .. pokemonName(mon) .. "!"
  end

  -- Gen1Recomp's TextBox is 18 vanilla cells wide and normally wraps at the
  -- previous space.  That can waste most of a row when a word such as
  -- "potential" almost fits.  Appraisal text gets a small, curated
  -- hyphenation layer before it reaches TextBox so useful row space is kept:
  -- e.g. "Its natural poten-" / "tial ...".  We then split the laid-out
  -- lines into independent two-line TextBoxes, preserving the rule that
  -- every visible box requires its own fresh A/B press.
  local HYPHEN_POINTS = {
    potential = { 5 },       -- poten- / tial (requested appraisal style)
  }

  -- Gen I's native <PK> and <MN> charmap sequences are two real font glyphs
  -- (the same compact pair used by vanilla Pokemon labels). Keep the full
  -- <PK><MN>'s possessive as one layout token so it never splits or hyphenates.
  local ATOMIC_WORDS = {
    [PKMN_POSSESSIVE] = true,
  }

  local function textWidth(text)
    local font = mod.ui and mod.ui.Font
    if font and type(font.width) == "function" then
      local ok, width = pcall(font.width, text)
      if ok and type(width) == "number" then return width end
    end
    -- Headless/test fallback. Production uses the public Font metrics above.
    return #tostring(text or "") * 8
  end

  local function maxTextBudget()
    local theme = mod.ui and mod.ui.Theme
    local box = theme and theme.textBox
    return ((box and box.maxCols) or 18) * 8
  end

  local function splitAtGlyphCount(word, count)
    local font = mod.ui and mod.ui.Font
    if font and type(font.split) == "function" then
      local ok, spans = pcall(font.split, word)
      if ok and type(spans) == "table" and spans[count] then
        local cut = spans[count].to
        return word:sub(1, cut), word:sub(cut + 1)
      end
    end
    -- All built-in appraisal words are ASCII; this fallback is only for
    -- headless tests before the runtime Font has been loaded.
    return word:sub(1, count), word:sub(count + 1)
  end

  local function hyphenSplit(word, available)
    if ATOMIC_WORDS[word] then return nil end
    local lower = word:lower():gsub("[^a-z]", "")
    local points = HYPHEN_POINTS[lower]
    if not points then return nil end

    -- Prefer the furthest approved break that fits the remaining row.
    for i = #points, 1, -1 do
      local left, right = splitAtGlyphCount(word, points[i])
      if left and right and right ~= "" and textWidth(left .. "-") <= available then
        return left .. "-", right
      end
    end
    return nil
  end

  local function wrapAppraisalLines(text)
    local budget = maxTextBudget()
    local lines = {}
    local current = ""

    local function flush()
      if current ~= "" then
        lines[#lines + 1] = current
        current = ""
      end
    end

    -- Appraisal source strings are semantic sentences. Explicit newlines are
    -- treated as spaces here; this formatter owns the final row layout.
    text = tostring(text or ""):gsub("[\n\r]+", " ")

    for originalWord in text:gmatch("%S+") do
      local word = originalWord
      while word and word ~= "" do
        local candidate = (current == "") and word or (current .. " " .. word)
        if textWidth(candidate) <= budget then
          current = candidate
          word = nil
        elseif current ~= "" then
          local prefix = current .. " "
          local left, right = hyphenSplit(word, budget - textWidth(prefix))
          if left then
            current = prefix .. left
            flush()
            word = right
          else
            flush()
          end
        else
          -- A single unbreakable word that is wider than the whole box is
          -- left to TextBox's glyph-safe fallback rather than cut blindly.
          current = word
          word = nil
        end
      end
    end
    flush()
    if #lines == 0 then lines[1] = "" end
    return lines
  end

  local function appraisalBoxes(text)
    local lines = wrapAppraisalLines(text)
    local boxes = {}
    for i = 1, #lines, 2 do
      if lines[i + 1] then
        boxes[#boxes + 1] = lines[i] .. "\n" .. lines[i + 1]
      else
        boxes[#boxes + 1] = lines[i]
      end
    end
    return boxes
  end

  local function dvMessages(mon)
    local sum = dvScore(mon)
    local tier = dvTier(sum)
    if tier == "outstanding" then
      return {
        "Your " .. PKMN_POSSESSIVE .. " DVs are outstanding!",
        "Its potential is remarkable!",
      }
    elseif tier == "above_average" then
      return {
        "Your " .. PKMN_POSSESSIVE .. " DVs are very good.",
        "Its potential is above average.",
      }
    elseif tier == "ordinary" then
      return {
        "Your " .. PKMN_POSSESSIVE .. " DVs are fairly ordinary.",
        "Its natural potential is decent.",
      }
    end
    return {
      "Your " .. PKMN_POSSESSIVE .. " DVs are rather low.",
      "Its natural potential is limited.",
    }
  end

  local function trainingMessages(mon, effectiveFn)
    local _, percent = trainingScore(mon, effectiveFn)
    local tier = trainingTier(percent)
    if tier == "complete" then
      return {
        "Its stats are fully developed!",
        "It reached its full potential!",
      }
    elseif tier == "nearly_complete" then
      return {
        "Its stats are remarkably high!",
        "It's very near its full potential.",
      }
    elseif tier == "well_trained" then
      return {
        "Its stats show lots of training.",
        "It still has room to grow!",
      }
    elseif tier == "developing" then
      return {
        "Its stats are growing nicely.",
        "It still needs lots of training.",
      }
    end
    return {
      "Its stats are still quite low.",
      "You two are just getting started!",
    }
  end

  local function expandMessageBoxes(messages)
    local out = {}
    for _, message in ipairs(messages or {}) do
      for _, boxText in ipairs(appraisalBoxes(message)) do
        out[#out + 1] = boxText
      end
    end
    return out
  end

  local function pushTextSequence(game, messages, onDone, index)
    index = index or 1
    if index > #messages then
      if onDone then onDone() end
      return
    end
    pushText(game, messages[index], function()
      pushTextSequence(game, messages, onDone, index + 1)
    end)
  end

  local function closeOak(game)
    local text = game.data and game.data.text
    local closed = text and text._ClosedOaksPCText
      or "Closed link to\nPROF.OAK's PC."
    pushText(game, closed)
  end

  local function appraisePokemon(game, mon, onDone, introText, effectiveFn)
    local messages = {}
    for _, text in ipairs(dvMessages(mon)) do messages[#messages + 1] = text end
    for _, text in ipairs(trainingMessages(mon, effectiveFn)) do messages[#messages + 1] = text end
    local boxes = expandMessageBoxes(messages)
    local finish = onDone or function() closeOak(game) end

    -- Speaker/name identification is intentionally isolated from the actual
    -- evaluation.  Gen 1 and Gold's remote Oak path use oakIntro unchanged;
    -- Gold's Happiness Rater supplies her own vanilla-style intro text.
    pushText(game, introText or oakIntro(mon), function()
      pushTextSequence(game, boxes, finish)
    end)
  end

  -- -----------------------------------------------------------------------
  -- Generation-specific orchestration.  The scoring/text/layout core above
  -- remains shared.  Backends install only after game.ready, when the live
  -- service owner exists; this keeps Gold away from Gen 1-only commands and
  -- keeps Gen 1's ui.pc.items hook away from Gold's Bill-PC storage context.

  local diagnostics = {
    generation = nil,
    backend = nil,
    pcOakInstalled = false,
    pcOakAvailable = false,
    personalAppraisalNpc = nil,
    personalAppraisalInstalled = false,
    happinessScriptKeyResolved = false,
    elmAppraisalNpc = nil,
    elmAppraisalInstalled = false,
    elmScriptKeyResolved = false,
    elmIdleScriptCount = 0,
    elmStartedSeen = 0,
    elmCommandSeen = 0,
    elmEndedSeen = 0,
    elmCompletedSeen = 0,
    lastContext = nil,
    lastSelectedSpecies = nil,
    lastSkipReason = nil,
  }

  local function diagnosticSnapshot()
    local out = {}
    for k, v in pairs(diagnostics) do
      if type(v) == "table" then
        local copy = {}
        for ck, cv in pairs(v) do copy[ck] = cv end
        out[k] = copy
      else
        out[k] = v
      end
    end
    return out
  end

  local function isGoldGame(game)
    -- Gold's service owner loads these generation-specific public data tables
    -- before game.ready.  This is a capability/generation check, not an engine
    -- version allow-list and therefore survives ordinary engine updates.
    local data = game and game.data
    return type(data) == "table"
      and type(data.gen2Maps) == "table"
      and type(data.gen2Scripts) == "table"
  end

  -- ------------------------------ Gen 1 -----------------------------------

  local gen1Installed = false

  local function installGen1()
    if gen1Installed then return end
    gen1Installed = true
    diagnostics.generation = 1
    diagnostics.backend = "gen1"

    local openOakChoice

    local function openPartyPicker(game, vanillaOakCallback)
      local party = (game.save and game.save.party) or {}
      if #party == 0 then
        pushText(game, "You don't have any\nPOKéMON with you!", function()
          openOakChoice(game, vanillaOakCallback)
        end)
        return
      end

      mod.ui.push(game, "PartyMenu", {
        forceSwitch = true,
        onSwitch = function(mon)
          appraisePokemon(game, mon)
        end,
        onCancel = function()
          openOakChoice(game, vanillaOakCallback)
        end,
      })
    end

    openOakChoice = function(game, vanillaOakCallback)
      local items = {
        {
          label = "SHOW POKéMON",
          onSelect = function()
            openPartyPicker(game, vanillaOakCallback)
          end,
        },
        {
          label = "SHOW POKéDEX",
          onSelect = function()
            -- Preserve the exact vanilla Oak Pokedex-rating flow by replaying
            -- the callback supplied by Gen1Recomp's own PROF.OAK's PC row.
            vanillaOakCallback()
          end,
        },
        { label = "CANCEL" },
      }
      game.stack:push(mod.ui.Menu.new(game, items, {
        tx = 5, ty = 4, tw = 15, noSound = true,
      }))
    end

    -- PROF.OAK's PC is assembled by the Gen 1 PC flow and then passed through
    -- this official hook.  This entire hook is installed only on Gen 1.
    mod.hooks:wrap("ui.pc.items", function(next, game, items)
      local out = next(game, items)
      if type(out) ~= "table" then return out end

      local decorated = {}
      local foundOak = false
      for _, item in ipairs(out) do
        if not foundOak and item.label == "PROF.OAK's PC"
            and type(item.onSelect) == "function" then
          local replacement = copyItem(item)
          local vanillaOakCallback = item.onSelect
          replacement.onSelect = function()
            openOakChoice(game, vanillaOakCallback)
          end
          decorated[#decorated + 1] = replacement
          foundOak = true
        else
          decorated[#decorated + 1] = item
        end
      end
      return decorated
    end, 100)

    -- Professor Oak's in-person lab dialogue reaches dex_rating only in the
    -- vanilla Pokédex-rating phase.  Resolve/assert the command here, after we
    -- know this is Gen 1, so a Gold boot never depends on this Gen 1 command.
    local commands = mod.content and mod.content.commands
    local vanillaDexRatingCommand = commands and commands:get("dex_rating")
    assert(type(vanillaDexRatingCommand) == "function",
      "oak_pokemon_appraisal: vanilla dex_rating command is unavailable")

    local function isInPersonOakDexContext(ctx)
      local ow = ctx and ctx.overworld
      return ow and ow.map and ow.map.id == "OAKS_LAB"
    end

    local function inPersonOakChoice(ctx)
      local game = ctx.game
      local runner = ctx.runner
      assert(game and runner,
        "oak_pokemon_appraisal: Oak lab command needs game/runner")

      while true do
        local choice
        local resumed = false
        local function choose(value)
          if resumed then return end
          resumed = true
          choice = value
          runner:resume()
        end

        game.stack:push(mod.ui.Menu.new(game, {
          { label = "SHOW POKéMON", onSelect = function() choose("pokemon") end },
          { label = "SHOW POKéDEX", onSelect = function() choose("pokedex") end },
          { label = "CANCEL",       onSelect = function() choose("cancel") end },
        }, {
          tx = 5, ty = 4, tw = 15,
          onCancel = function() choose("cancel") end,
        }))
        runner:yield()

        if choice == "pokedex" then
          return vanillaDexRatingCommand(ctx)
        elseif choice == "cancel" then
          return
        elseif choice == "pokemon" then
          local party = (game.save and game.save.party) or {}
          if #party == 0 then
            pushText(game, "You don't have any\nPOKéMON with you!", function()
              runner:resume()
            end)
            runner:yield()
          else
            local selected
            local partyCancelled = false
            mod.ui.push(game, "PartyMenu", {
              forceSwitch = true,
              onSwitch = function(mon)
                selected = mon
                runner:resume()
              end,
              onCancel = function()
                partyCancelled = true
                runner:resume()
              end,
            })
            runner:yield()

            if selected then
              appraisePokemon(game, selected, function()
                runner:resume()
              end)
              runner:yield()
              return
            elseif not partyCancelled then
              return
            end
            -- B from PartyMenu returns to Oak's three-way choice.
          end
        end
      end
    end

    commands:override("dex_rating", function(ctx, ...)
      if not isInPersonOakDexContext(ctx) then
        return vanillaDexRatingCommand(ctx, ...)
      end
      return inPersonOakChoice(ctx)
    end)
  end

  -- ------------------------------ Gold ------------------------------------

  local GOLD_HAPPINESS_MAP = "GOLDENROD_HAPPINESS_RATER"
  local GOLD_HAPPINESS_GROUP = 11
  local GOLD_HAPPINESS_NUMBER = 5
  local GOLD_HAPPINESS_TEACHER_OBJECT = 1
  local GOLD_HAPPINESS_SPECIAL = "GetFirstPokemonHappiness"
  local GOLD_ELM_MAP = "ELMS_LAB"
  local GOLD_ELM_GROUP = 24
  local GOLD_ELM_NUMBER = 5
  local GOLD_ELM_OBJECT = 1
  local GOLD_CENTER_PC_SCREEN = "Gen2CenterPcMenu"
  local GOLD_PARTY_SCREEN = "Gen2PartyMenu"

  local goldInstalled = false
  local goldGame = nil
  local happinessTeacherScriptKey = nil
  -- Elm's imported root pointer is diagnostics/fallback only.  Live appraisal
  -- must not depend on it: the canonical interaction is identified by the
  -- Elm's Lab map plus Elm's NPC object and observed vanilla faceplayer beat.
  local elmScriptKey = nil
  local elmConversationActive = false
  local elmConversationVm = nil

  local function findMapDef(maps, id)
    if type(maps) ~= "table" then return nil end
    if type(maps[id]) == "table" then return maps[id] end
    for _, def in pairs(maps) do
      if type(def) == "table" and (def.id == id or def.name == id) then
        return def
      end
    end
    return nil
  end

  local function resolveObjectScriptKey(game, mapId, objectIndex)
    local maps = game and game.data and game.data.gen2Maps
    local mapDef = findMapDef(maps, mapId)
    local objects = mapDef and (mapDef.objects or mapDef.objectEvents)
    local object = objects and objects[objectIndex]
    if type(object) ~= "table" then return nil end
    return object.scriptKey or object.script or object.scriptId
  end

  local function resolveHappinessTeacherScriptKey(game)
    return resolveObjectScriptKey(game, GOLD_HAPPINESS_MAP,
      GOLD_HAPPINESS_TEACHER_OBJECT)
  end

  local function isEgg(mon)
    return type(mon) == "table" and mon.isEgg == true
  end

  local function raterIntro(mon)
    return "Oh? Let me see\nyour " .. pokemonName(mon) .. "..."
  end

  local function elmIntro(mon)
    return "ELM: Let's see...\n" .. pokemonName(mon) .. "!"
  end

  local function selectedSpecies(mon)
    if type(mon) ~= "table" or mon.isEgg then return nil end
    return mon.species
  end

  local function popTop(game)
    if game and game.stack and type(game.stack.pop) == "function" then
      game.stack:pop()
    end
  end

  local function goldPartyPicker(game, onChoose, onCancel)
    mod.ui.push(game, GOLD_PARTY_SCREEN, {
      party = game.save and game.save.party or {},
      prompt = "choose",
      -- No submenu: Gen2PartyMenu's default contract is direct selection.
      onChoose = function(_, mon)
        popTop(game)
        if onChoose then onChoose(mon) end
      end,
      onCancel = function()
        popTop(game)
        if onCancel then onCancel() end
      end,
    })
  end

  local openGoldOakChoice
  local openGoldOakPartyPicker

  openGoldOakPartyPicker = function(center)
    local game = center.game or goldGame
    goldPartyPicker(game, function(mon)
      if isEgg(mon) then
        diagnostics.lastSkipReason = "egg"
        pushText(game, "An EGG can't be\nappraised yet.", function()
          openGoldOakPartyPicker(center)
        end)
        return
      end
      diagnostics.lastSelectedSpecies = selectedSpecies(mon)
      diagnostics.lastSkipReason = nil
      appraisePokemon(game, mon, function()
        -- Native Gold close-link copy and return behavior.
        center:oakClosed()
      end, nil, effectiveStatExpGold)
    end, function()
      openGoldOakChoice(center)
    end)
  end

  openGoldOakChoice = function(center)
    local game = center.game or goldGame
    local originalChoose = center._oakPokemonAppraisalOriginalChoose
    game.stack:push(mod.ui.Menu.new(game, {
      {
        label = "SHOW POKéMON",
        onSelect = function() openGoldOakPartyPicker(center) end,
      },
      {
        label = "SHOW POKéDEX",
        onSelect = function()
          -- Run the captured native CenterPcMenu:choose with the `oaks` row
          -- still selected, preserving Gold's intro, counts, rating and close.
          if originalChoose then return originalChoose(center) end
        end,
      },
      { label = "CANCEL" },
    }, {
      tx = 5, ty = 4, tw = 15, noSound = true,
    }))
  end

  local function decorateGoldCenterPc(center)
    if type(center) ~= "table"
        or center.screenId ~= GOLD_CENTER_PC_SCREEN
        or type(center.choose) ~= "function"
        or type(center.oakClosed) ~= "function"
        or type(center.entries) ~= "table" then
      return false
    end
    if center._oakPokemonAppraisalInstalled then return true end

    local originalChoose = center.choose
    center._oakPokemonAppraisalInstalled = true
    center._oakPokemonAppraisalOriginalChoose = originalChoose
    center.choose = function(self, ...)
      local entry = self.entries and self.entries[self.index]
      if not (entry and entry.id == "oaks") then
        return originalChoose(self, ...)
      end
      diagnostics.pcOakAvailable = true
      return openGoldOakChoice(self)
    end
    diagnostics.pcOakInstalled = true

    -- Availability is native/save-driven: before ENGINE_POKEDEX there is no
    -- `oaks` row, and the decorator never manufactures one.
    for _, entry in ipairs(center.entries) do
      if entry.id == "oaks" then diagnostics.pcOakAvailable = true break end
    end
    return true
  end

  local function resumeVmOnce(vm, setter)
    local fired = false
    return function(...)
      if fired then return end
      fired = true
      if setter then setter(...) end
      vm:resume()
    end
  end

  local function specialId(args, cmd)
    if type(cmd) == "table" then
      if cmd.special ~= nil then return cmd.special end
      if cmd.id ~= nil then return cmd.id end
      if cmd.specialId ~= nil then return cmd.specialId end
    end
    return type(args) == "table" and args[1] or nil
  end

  local function specialName(ctx, args, cmd)
    local vm = ctx and ctx.vm
    if not (vm and type(vm.specialName) == "function") then return nil end
    return vm:specialName(specialId(args, cmd))
  end

  local function isExactHappinessRaterContext(ctx, name, args, cmd)
    if type(ctx) ~= "table" or ctx.generation ~= 2 then return false end
    if name ~= "special" then return false end
    if ctx.mapId ~= GOLD_HAPPINESS_MAP then return false end
    if ctx.mapGroup ~= GOLD_HAPPINESS_GROUP then return false end
    if ctx.mapNumber ~= GOLD_HAPPINESS_NUMBER then return false end
    if ctx.object ~= GOLD_HAPPINESS_TEACHER_OBJECT then return false end
    if not happinessTeacherScriptKey
        or ctx.scriptKey ~= happinessTeacherScriptKey then return false end
    return specialName(ctx, args, cmd) == GOLD_HAPPINESS_SPECIAL
  end

  local function rememberGoldContext(ctx, special)
    diagnostics.lastContext = {
      generation = ctx and ctx.generation,
      scriptKey = ctx and ctx.scriptKey,
      kind = ctx and ctx.kind,
      mapId = ctx and ctx.mapId,
      mapGroup = ctx and ctx.mapGroup,
      mapNumber = ctx and ctx.mapNumber,
      object = ctx and ctx.object,
      special = special,
    }
  end

  local function waitForRaterRootChoice(game, vm)
    local choice
    local resume = resumeVmOnce(vm, function(value) choice = value end)
    game.stack:push(mod.ui.Menu.new(game, {
      { label = "CHECK HAPPINESS", onSelect = function() resume("happiness") end },
      { label = "APPRAISE",        onSelect = function() resume("appraise") end },
      { label = "CANCEL",          onSelect = function() resume("cancel") end },
    }, {
      tx = 2, ty = 4, tw = 18,
      onCancel = function() resume("cancel") end,
    }))
    coroutine.yield()
    return choice
  end

  local function waitForGoldAppraisalPokemon(game, vm)
    while true do
      local selected
      local cancelled = false
      local resume = resumeVmOnce(vm, function(mon, wasCancelled)
        selected = mon
        cancelled = wasCancelled == true
      end)
      goldPartyPicker(game,
        function(mon) resume(mon, false) end,
        function() resume(nil, true) end)
      coroutine.yield()

      if cancelled then return nil, "cancel" end
      if selected and isEgg(selected) then
        diagnostics.lastSkipReason = "egg"
        local continueAfterEgg = resumeVmOnce(vm)
        pushText(game, "An EGG can't be\nappraised yet.", continueAfterEgg)
        coroutine.yield()
      elseif selected then
        return selected, "selected"
      else
        return nil, "cancel"
      end
    end
  end

  local function runGoldHappinessRater(next, ctx, name, args, cmd)
    local game = goldGame
    local vm = ctx.vm
    assert(game and vm,
      "oak_pokemon_appraisal: Gold Happiness Rater needs game/vm")

    rememberGoldContext(ctx, GOLD_HAPPINESS_SPECIAL)
    while true do
      local choice = waitForRaterRootChoice(game, vm)
      if choice == "happiness" then
        diagnostics.lastSkipReason = nil
        -- Exactly one native call: the cart special computes first non-Egg
        -- happiness/string buffer, then the untouched following script picks
        -- one of Gold's six vanilla threshold branches.
        return next(ctx, name, args, cmd)
      elseif choice == "cancel" then
        diagnostics.lastSkipReason = "cancel"
        return "end"
      elseif choice == "appraise" then
        local mon, status = waitForGoldAppraisalPokemon(game, vm)
        if status == "cancel" then
          -- Party B returns to CHECK HAPPINESS / APPRAISE / CANCEL.
        elseif mon then
          diagnostics.lastSelectedSpecies = selectedSpecies(mon)
          diagnostics.lastSkipReason = nil
          local resumeAfterAppraisal = resumeVmOnce(vm)
          appraisePokemon(game, mon, resumeAfterAppraisal, raterIntro(mon),
            effectiveStatExpGold)
          coroutine.yield()
          -- Do not fall through into the cart's happiness writetext/ifgreater
          -- chain after a custom appraisal.
          return "end"
        end
      end
    end
  end

  local openElmPostDialogueChoice
  local openElmPostDialoguePartyPicker

  local function isElmLabContext(ctx)
    if type(ctx) ~= "table" or ctx.generation ~= 2 then return false end
    -- Gold exposes both a friendly mapId and the cartridge group/number pair.
    -- Accept either canonical representation so the integration does not
    -- disappear merely because one convenience field is absent in a runtime.
    if ctx.mapId == GOLD_ELM_MAP then return true end
    return ctx.mapGroup == GOLD_ELM_GROUP
      and ctx.mapNumber == GOLD_ELM_NUMBER
  end

  local function isElmNpcContext(ctx)
    if not isElmLabContext(ctx) then return false end
    -- hLastTalked/object 1 is Professor Elm.  The dynamically resolved root
    -- pointer remains a secondary fallback for runtimes that omit object.
    if ctx.object == GOLD_ELM_OBJECT then return true end
    return elmScriptKey ~= nil and ctx.scriptKey == elmScriptKey
  end

  local function markElmConversation(ctx, name)
    -- ProfElmScript starts with `faceplayer`.  Observing that exact vanilla
    -- command on Elm's NPC is enough to prove this run is an Elm conversation.
    -- Nothing is intercepted or replaced; the command still runs natively.
    if name ~= "faceplayer" or not isElmNpcContext(ctx) then return end
    elmConversationActive = true
    elmConversationVm = ctx.vm
    diagnostics.elmCommandSeen = diagnostics.elmCommandSeen + 1
    diagnostics.lastSkipReason = nil
  end

  local function onGoldScriptStarted(ev)
    local ctx = ev and ev.ctx
    if type(ctx) ~= "table" or ctx.generation ~= 2 then return end
    -- A new top-level Gold run invalidates a stale marker from an abandoned
    -- conversation.  This event is only bookkeeping; it never opens UI.
    elmConversationActive = false
    elmConversationVm = nil
    if isElmNpcContext(ctx) then
      diagnostics.elmStartedSeen = diagnostics.elmStartedSeen + 1
    end
  end

  openElmPostDialoguePartyPicker = function(game)
    local party = game.save and game.save.party or {}
    if type(party) ~= "table" or #party == 0 then
      diagnostics.lastSkipReason = "no-party"
      return
    end

    goldPartyPicker(game, function(mon)
      if isEgg(mon) then
        diagnostics.lastSkipReason = "egg"
        pushText(game, "An EGG can't be\nappraised yet.", function()
          openElmPostDialoguePartyPicker(game)
        end)
        return
      end

      diagnostics.lastSelectedSpecies = selectedSpecies(mon)
      diagnostics.lastSkipReason = nil
      appraisePokemon(game, mon, function() end, elmIntro(mon), effectiveStatExpGold)
    end, function()
      openElmPostDialogueChoice(game)
    end)
  end

  openElmPostDialogueChoice = function(game)
    game.stack:push(mod.ui.Menu.new(game, {
      { label = "APPRAISE", onSelect = function()
          openElmPostDialoguePartyPicker(game)
        end },
      { label = "CANCEL" },
    }, {
      tx = 5, ty = 6, tw = 15,
    }))
  end

  local function onGoldScriptEnded(ev)
    local ctx = ev and ev.ctx
    if type(ctx) ~= "table" or ctx.generation ~= 2 then return end

    diagnostics.elmEndedSeen = diagnostics.elmEndedSeen +
      (isElmLabContext(ctx) and 1 or 0)

    -- The appraisal is armed only by observing Elm's own vanilla `faceplayer`
    -- command in this exact run.  This avoids false positives from hLastTalked,
    -- which Gold intentionally leaves stale for signs and callbacks.
    local wasElmConversation = elmConversationActive and
      (elmConversationVm == nil or ctx.vm == nil or ctx.vm == elmConversationVm)

    -- Always clear before doing UI work so no stale Elm identity can leak into
    -- the next script, including an aborted or map-changing conversation.
    elmConversationActive = false
    elmConversationVm = nil

    if ev.completed ~= true or not wasElmConversation then return end

    local game = goldGame
    local party = game and game.save and game.save.party or nil
    if not game or type(party) ~= "table" or #party == 0 then
      diagnostics.lastSkipReason = "elm-no-party"
      return
    end

    -- `script.ended` is after the ENTIRE vanilla ProfElmScript run.  The mod
    -- never changes Elm's command result or control flow; all story text, event
    -- flags and rewards therefore finish first.  This menu is a separate UI
    -- append that starts only after successful native completion.
    diagnostics.elmCompletedSeen = diagnostics.elmCompletedSeen + 1
    rememberGoldContext(ctx, "ProfessorElmPostDialogue")
    diagnostics.lastSkipReason = nil
    openElmPostDialogueChoice(game)
  end

  local function installGold(game)
    if goldInstalled then return end
    goldInstalled = true
    goldGame = game
    diagnostics.generation = 2
    diagnostics.backend = "gold"
    diagnostics.personalAppraisalNpc = "Goldenrod Happiness Rater"
    diagnostics.elmAppraisalNpc = "Professor Elm"

    happinessTeacherScriptKey = resolveHappinessTeacherScriptKey(game)
    diagnostics.happinessScriptKeyResolved = happinessTeacherScriptKey ~= nil
    diagnostics.personalAppraisalInstalled = happinessTeacherScriptKey ~= nil
    if not happinessTeacherScriptKey then
      diagnostics.lastSkipReason = "happiness-script-key-unresolved"
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("Gold Happiness Rater scriptKey could not be resolved; personal appraisal disabled safely")
      end
    end

    elmScriptKey = resolveObjectScriptKey(game, GOLD_ELM_MAP, GOLD_ELM_OBJECT)
    diagnostics.elmScriptKeyResolved = elmScriptKey ~= nil
    diagnostics.elmIdleScriptCount = 0
    -- Elm no longer depends on the imported root script pointer.  Map/NPC
    -- provenance plus an observed vanilla faceplayer command is authoritative.
    diagnostics.elmAppraisalInstalled = true

    mod.events:on("screen.pushed", function(ev)
      local state = ev and ev.state
      if state and state.screenId == GOLD_CENTER_PC_SCREEN then
        decorateGoldCenterPc(state)
      end
    end)

    -- Elm is observed, never intercepted.  `script.started` only clears stale
    -- bookkeeping; `script.command` marks the vanilla `faceplayer`; and only
    -- `script.ended` may append UI after the whole story branch is finished.
    mod.events:on("script.started", onGoldScriptStarted)
    mod.events:on("script.ended", onGoldScriptEnded)

    mod.hooks:wrap("script.command", function(next, ctx, name, args, cmd)
      markElmConversation(ctx, name)
      if happinessTeacherScriptKey
          and isExactHappinessRaterContext(ctx, name, args, cmd) then
        return runGoldHappinessRater(next, ctx, name, args, cmd)
      end
      return next(ctx, name, args, cmd)
    end, 100)
  end

  -- Content registries are frozen before game.ready on v0.1.86.  The Gen I
  -- backend owns the dex_rating command override, so it must be installed
  -- during the entry chunk.  Capability detection keeps Gold isolated: its
  -- command registry intentionally contains no Gen I built-in verbs.
  local entryCommands = mod.content and mod.content.commands
  if entryCommands and type(entryCommands:get("dex_rating")) == "function" then
    installGen1()
  end

  -- Gold needs the live Game2 owner and generated map/script tables.  Those
  -- are available in game.ready; Gold registers only runtime hooks/events at
  -- that point, which remain legal for the life of the process.
  mod.events:on("game.ready", function(ev)
    local game = ev and ev.game
    if not game then return end
    if isGoldGame(game) then
      installGold(game)
    end
  end)

  -- Small read-only API: useful for tests and compatible UI mods.
  mod.exports.version = MOD_VERSION
  mod.exports.effectiveStatExp = effectiveStatExp
  mod.exports.effectiveStatExpGold = effectiveStatExpGold
  mod.exports.scoreDVs = function(mon)
    local sum, percent = dvScore(mon)
    return { sum = sum, max = MAX_DV_SUM, percent = percent, tier = dvTier(sum) }
  end
  mod.exports.scoreTraining = function(mon)
    local sum, percent = trainingScore(mon)
    return { sum = sum, max = MAX_TRAINING_SUM, percent = percent,
             tier = trainingTier(percent) }
  end
  mod.exports.scoreTrainingGold = function(mon)
    local sum, percent = trainingScore(mon, effectiveStatExpGold)
    return { sum = sum, max = MAX_TRAINING_SUM, percent = percent,
             tier = trainingTier(percent) }
  end
  mod.exports.layoutAppraisalText = function(text)
    return appraisalBoxes(text)
  end
  mod.exports.diagnostics = diagnosticSnapshot
end
