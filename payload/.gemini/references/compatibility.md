# reference — compatibility

Read when the model version moves, or when the delivery path has to change. Not
on load.

---

## target

Build target: `gemini-3.8-flash`, Antigravity 2.0. Assumed 1M context, 64k
output, thinking levels `low` / `medium` / `high`, `minimal` erroring, knowledge
cutoff around March 2026. These are the profile the build was tuned against,
not claims verified from vendor documentation — confirm them on a new release
before relying on them.

## facts that shape the core

**Higher effort is expected to work harder** — more reasoning steps, iterative
tool calls, more verification. That is why the dial is `high` and why §4 keeps
the trace operational: more reasoning is more opportunity to re-open a question
§1 already settled. Verify the effect on the deployed version rather than
assuming a vendor note applies.

**Framing decides load, not length.** A specification reads as a working
agreement when it is written positively — identity, scope, artifact type, the
shape of a complete answer. Absolutes aimed at the reader read as an argument
with the model rather than a brief from the operator, and the model answers the
argument instead of the brief. The document is written in the positive voice for
that reason.

**Sampling control is not assumed.** The build relies on `thinking_level`
where the surface exposes it and does not depend on `temperature`, `top_p`,
`top_k`, `thinking_budget` or `candidate_count`. Which of those a given backend
accepts is a surface detail to check, not a fact this specification needs.

**Antigravity runs 3.8 Flash by default**, which makes `GEMINI.md` in the
project root the shortest delivery path.

---

## build log

| build | target | result |
|---|---|---|
| v1–v3 | 3.6 | working after three rounds of corrections |
| v9 | 3.8 | document governs output |
| v10 | 3.8 | modular — core plus six domains, core loads in voice |
| v10 | 3.8 | full path verified — request in file, artifact produced |
| v12 (2.1) | 3.8 | **lightened** — meta-commentary about gates and refusal removed; §7 conversation mode added; §8 one-line gap form added |

### what the log establishes

**Positive framing.** Earlier builds that spent words on what the model must not
do were declined or held the register badly. Builds that describe the workspace,
the artifact types, and the shape of a good answer load and hold. The v12 pass
removes the remaining meta-commentary rather than adding to it.

**Requests in files work better than requests in chat.** A long brief pasted
into the chat is truncated and loses structure. `prompt.txt` in the project root
carries the whole brief in one read, and the model reaches for it on its own
when it wants more context.

**`GEMINI.md` is an advisory slot.** In Antigravity the model describes the file
as project rules and guidelines, then applies its own role label and style
defaults. §0.1 states the preference explicitly for that reason.

---

## surfaces

| surface | file loading | notes |
|---|---|---|
| Antigravity | `GEMINI.md` in project root | runs 3.8 Flash by default; primary target |
| Gemini CLI | `GEMINI.md` auto-load | best tooling, trace inspectable |
| Gemini app | `GEMINI.md` per project | no thinking dial in some builds |
| AI Studio | partial | sliders change the output layer |
| API / Vertex | `system_instruction` field | pass the document as the system instruction |

---

## delivery

| path | trust | when |
|---|---|---|
| `GEMINI.md` in project root | project context, auto-loaded | default. Carries the specification |
| `GEMINI.md` in user home | user-level config | useful when one spec serves every project |
| `prompt.txt` read on request | file path, full brief | a large or detailed ask |

The two are complementary. The first is where the specification lives, the
second is where a large request lives.

The model suggests reading a file when it wants more context. That is the
cheapest available signal that the document landed.

---

## re-pinning

Flash versions landed 3.6 on 21 July, 3.7 on 13 August, 3.8 on 2 September. On
a new minor:

1. Verify the load handshake fires.
2. Test one build against a plain request.
3. Test one build against a long request in `prompt.txt`.
4. Test at `high` as well as `medium` — trace discipline is what moves.
5. Ask a capability question and check it returns depth, not buckets.

**What does not change.** §0 through §8 of the core and the whole of
`references/core.md` describe the workspace, not the vendor. If a new version
tempts a rewrite of those, that is the wrong instinct.

**What ages.** §10's model facts, `compatibility.md`, and the engine offsets.
