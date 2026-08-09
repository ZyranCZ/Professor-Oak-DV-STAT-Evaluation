# Professor Oak's Pokémon Appraisal

A small Gen1Recomp mod that lets **Professor Oak appraise your Pokémon**, using the real hidden stat systems from Pokémon Red/Blue.

Oak can appraise Pokémon through:

- **Professor Oak's PC**
- **Professor Oak himself in his laboratory**

The menu offers:

```text
SHOW POKéMON
SHOW POKéDEX
CANCEL
```
<img width="931" height="888" alt="image" src="https://github.com/user-attachments/assets/a548e886-a478-4d78-a497-a1d564d9519a" />


**Check out my other mods:**<br>
* [Autofire A/B + Directional Keys Mod](https://github.com/ZyranCZ/autofire)<br>
* [Steel and/or Fairy and/or Typing Charts](https://github.com/ZyranCZ/Steel-and-or-Fairy-and-or-Typing-Charts)<br>
* [Move Category (PHYS/SPEC) Preview](https://github.com/ZyranCZ/Move-Category-Preview)<br>
* [Special Stat Split
](https://github.com/ZyranCZ/Special-Stat-Split/)<br>
* [Enemy HP Visible](https://github.com/ZyranCZ/Enemy-HP)
* [Can Always Escape](https://github.com/ZyranCZ/Can-Always-Escape)
* [Trainers Let You Choose Lead Pokemon](https://github.com/ZyranCZ/Trainers-Let-You-Choose-Lead-Pokemon)
* [Evolve in Battle](https://github.com/ZyranCZ/Evolve-in-Battle)
* [HELP Story Guide](https://github.com/ZyranCZ/HELP-Story-Guide/)
* [Professor Oak's Pokémon DV/Stat Appraisal](https://github.com/ZyranCZ/Professor-Oak-DV-STAT-Evaluation)



`SHOW POKéDEX` keeps the original Red/Blue Pokédex evaluation.

`SHOW POKéMON` lets you choose a Pokémon from your current party and evaluates two separate things:

- **DVs** — its natural potential
- **Stat Experience** — how much it has been trained

## What are DVs?

**DVs (Determinant Values)** are the Generation I predecessor of modern **IVs (Individual Values)**.

Attack, Defense, Speed and Special each have a hidden DV from **0–15**, for a maximum total of **60**.

DVs are determined when a Pokémon is obtained and **cannot be improved through training**.

In simple terms:

**DVs = natural talent**

| Total DVs | Oak's appraisal |
|---:|---|
| **50–60** | `Your <PK><MN>'s DVs are outstanding!` / `Its potential is remarkable!` |
| **40–49** | `Your <PK><MN>'s DVs are very good.` / `Its potential is above average.` |
| **31–39** | `Your <PK><MN>'s DVs are fairly ordinary.` / `Its natural potential is decent.` |
| **0–30** | `Your <PK><MN>'s DVs are rather low.` / `Its natural potential is limited.` |
<img width="931" height="888" alt="image" src="https://github.com/user-attachments/assets/4181c8fe-fbfe-429b-9c1b-12c90fde5e48" />

## What is Stat Experience?

**Stat Experience** is the Generation I predecessor of modern **EVs (Effort Values)**.

Pokémon gain separate Stat Experience for:

- HP
- Attack
- Defense
- Speed
- Special

Unlike DVs, Stat Experience **increases through battling**.

The mod evaluates the effective stat growth produced by Stat Experience. Each stat can contribute up to 63 effective training points, for a total maximum of **315**.

In simple terms:

**Stat Experience = training**

| Training | Oak's appraisal |
|---:|---|
| **315 / 315** | `Its stats are fully developed!` / `It reached its full potential!` |
| **221–314** | `Its stats are remarkably high!` / `It's very near its full potential.` |
| **127–220** | `Its stats show lots of training.` / `It still has room to grow!` |
| **64–126** | `Its stats are growing nicely.` / `It still needs lots of training.` |
| **0–63** | `Its stats are still quite low.` / `You two are just getting started!` |
<img width="931" height="888" alt="image" src="https://github.com/user-attachments/assets/95ac729d-e74c-4bdf-8034-fbd6d107a475" />

## DVs vs. Training

The two systems are independent.

A Pokémon can have excellent DVs but little training, poor DVs but maximum training, or anything in between.

Its **level is separate from both**.

> **DVs = talent**  
> **Stat Experience = training**

## Notes

- The mod does not change DVs, Stat Experience, leveling or battle mechanics.
- It only exposes information that already exists internally.
- Appraisal dialogue is split into short Game Boy-style messages, with each box requiring its own button press.
- The original Red/Blue `<PK><MN>` glyphs are used in appraisal text to keep the layout consistent for every Pokémon.

## Compatibility

Built for **Gen1Recomp v0.1.75**.

## Version

**1.0.0**
