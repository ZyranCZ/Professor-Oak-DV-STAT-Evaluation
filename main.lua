-- PROFESSOR OAK'S POKEMON APPRAISAL v1.0.1
-- Target: Gen1Recomp v0.1.75 / commit 60cf07fb0a1ffce0ec6d5d0d2f78a921a6d0b7da
--
-- Adds the same SHOW POKEMON / SHOW POKEDEX appraisal choice to PROF.OAK's PC and
-- to Professor Oak himself once his normal lab dialogue reaches the Pokédex-rating phase.
-- POKEMON appraisal reports immutable Gen I DVs and battle-grown Stat Experience.

local MOD_VERSION = "1.0.1"
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

-- Mirrors Gen1Recomp v0.1.75 Stats.calc's Stat Experience contribution:
-- floor(min(255, ceil(sqrt(statExp))) / 4), i.e. 0..63 per stat.
-- This measures effective training potential rather than raw 0..65535 storage.
local function effectiveStatExp(statExp)
  local value = clampNumber(statExp, 0, 65535)
  return math.floor(math.min(255, math.ceil(math.sqrt(value))) / 4)
end

local function dvScore(mon)
  local dvs = (type(mon) == "table" and mon.dvs) or {}
  local sum = clampNumber(dvs.attack, 0, 15)
            + clampNumber(dvs.defense, 0, 15)
            + clampNumber(dvs.speed, 0, 15)
            + clampNumber(dvs.special, 0, 15)
  return sum, (sum / MAX_DV_SUM) * 100
end

local function trainingScore(mon)
  local statExp = (type(mon) == "table" and mon.statExp) or {}
  local sum = 0
  for _, key in ipairs(STAT_EXP_KEYS) do
    sum = sum + effectiveStatExp(statExp[key])
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

  local function trainingMessages(mon)
    local _, percent = trainingScore(mon)
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

  local function appraisePokemon(game, mon, onDone)
    local messages = {}
    for _, text in ipairs(dvMessages(mon)) do messages[#messages + 1] = text end
    for _, text in ipairs(trainingMessages(mon)) do messages[#messages + 1] = text end
    local boxes = expandMessageBoxes(messages)
    local finish = onDone or function() closeOak(game) end

    -- Speaker/name identification is intentionally isolated from the actual
    -- evaluation. It is always one two-line TextBox, then the deterministic
    -- <PK><MN>'s appraisal copy follows without repeated OAK: prefixes.
    pushText(game, oakIntro(mon), function()
      pushTextSequence(game, boxes, finish)
    end)
  end

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

  local function beginPokemonAppraisal(game, vanillaOakCallback)
    openPartyPicker(game, vanillaOakCallback)
  end

  openOakChoice = function(game, vanillaOakCallback)
    local items = {
      {
        label = "SHOW POKéMON",
        onSelect = function()
          beginPokemonAppraisal(game, vanillaOakCallback)
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

  -- PROF.OAK's PC is assembled by OverworldState:openPC and then passed
  -- through this official hook. We call next first so every lower-priority
  -- mod keeps its edits, then replace only Oak's callback while preserving
  -- all other descriptor fields (including keepOpen).
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


  -- Professor Oak's in-person lab dialogue already reaches the engine's
  -- `dex_rating` script command only when vanilla considers Oak ready to
  -- rate the Pokédex. Intercept that single command rather than replacing
  -- TEXT_OAKSLAB_OAK1: all starter/parcel/Pokédex/Poké Ball story branches
  -- therefore remain the original engine script. Outside OAKS_LAB the
  -- captured vanilla command is delegated unchanged.
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
    assert(game and runner, "oak_pokemon_appraisal: Oak lab command needs game/runner")

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
        -- We are back inside the script coroutine here, so the captured
        -- blocking vanilla command may yield/resume exactly as normal.
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
            -- Same appraisal sequence as the PC path, but talking to Oak in
            -- person ends back in the lab rather than printing the PC-only
            -- "Closed link to PROF.OAK's PC." line.
            appraisePokemon(game, selected, function()
              runner:resume()
            end)
            runner:yield()
            return
          elseif not partyCancelled then
            return
          end
          -- B from PartyMenu returns to Oak's SHOW POKEMON / SHOW POKEDEX choice.
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

  -- Small read-only API: useful for tests and compatible UI mods.
  mod.exports.version = MOD_VERSION
  mod.exports.effectiveStatExp = effectiveStatExp
  mod.exports.scoreDVs = function(mon)
    local sum, percent = dvScore(mon)
    return { sum = sum, max = MAX_DV_SUM, percent = percent, tier = dvTier(sum) }
  end
  mod.exports.scoreTraining = function(mon)
    local sum, percent = trainingScore(mon)
    return { sum = sum, max = MAX_TRAINING_SUM, percent = percent,
             tier = trainingTier(percent) }
  end
  mod.exports.layoutAppraisalText = function(text)
    return appraisalBoxes(text)
  end
end
