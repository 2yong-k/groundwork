# Project profile check — the first message of `/groundwork:new` stage 2

Right after the stage 1 summary is approved, the **first message** of stage 2 shows the table below filled with your estimate and asks "Correct only the wrong cells" (one question). The rows that are on decide which modules get asked later.

## A. Rows (P1–P9)

| Row | Asks | Module it turns on |
|---|---|---|
| P1 | Do quantities that must never be wrong change hands, such as money, assets or points? | Numbers and units |
| P2 | Are there two or more servers, or scheduled jobs, workers or queues? | Multiple instances and async |
| P3 | Are there APIs, uploads, websockets or proxies reachable without login? | Public surface |
| P4 | Does AI or LLM output drive product behavior? | AI pipeline |
| P5 | Two or more languages, or does search visibility matter? | i18n and URLs |
| P6 | Are there more apps besides the user app, such as admin or docs? | Multiple apps |
| P7 | Are there external dependencies that may change, such as payments, chain, auth SDKs or data providers? | External dependencies |
| P8 | Is it a large project spanning several sessions and several weeks? | Heavy operations kit |
| P9 | Does a server or operator hold a key that sends assets to destinations not fixed in advance or signs values that decide where money goes (settlement results · prices), or does money leave through a user session or wallet in a web or native app? | Money-moving keys |

## B. Rules for estimating rows from the stage 1 answers

Look for the signal words below in the stage 1 summary (users · scenarios · scope · out of scope). If even one is there, fill "yes"; with no signal, fill "no". The reason for a "yes" must be words quoted from the stage 1 answers — do not turn a row on with only "might be …" or "possibly" and nothing to quote (each row that is on adds one module message). If there are words close to a signal and it is unclear whether they count, set "yes" and write "estimate" in the reason so the user can correct it (missing one costs more).

| Row | Signal words |
|---|---|
| P1 | payments, balance · points, settlement · fees |
| P2 | scheduled jobs · cron, workers · queues, several servers |
| P3 | public API, uploads · websockets, receiving webhooks · proxy |
| P4 | AI · LLM, prompts, agents |
| P5 | two or more languages, overseas users, search visibility · SEO |
| P6 | admin · back office, docs site, two or more apps |
| P7 | payment provider · auth SDK, blockchain · wallet, external data provider |
| P8 | several weeks or more, several sessions · several people, staged releases |
| P9 | wallet · hot wallet, contract deploy · admin, withdrawals · payouts · transfers (sending money to users), sell · order signing, signing settlement results · prices (oracle) |

Small CLIs, scripts and libraries usually have P8 "no". With P8 off, no ledger or handoff gets made.

Tokens · refunds are not P9 signals — they overlap with design and auth tokens. A payment provider key that can only refund is P7.

## C. Message format

End with one table and a one-line note. Next to each row write **a one-phrase reason** (a quote from the stage 1 answers, or "no signal").

```
Here is how I read the project profile.

| Row | yes/no | Reason |
|---|---|---|
| P1 Numbers and units | yes | "earn and spend points" |
| P2 Multiple instances · async | no | no signal |
| … 9 rows through P9 | | |

Correct only the wrong cells. (e.g. "P2 yes, P5 no")
```

Apply the cells the user corrected, confirm the table, and commit it to `CONTEXT.md` right away. From then on ask only the modules of the rows that are on.

## D. The `## Project profile` table in `CONTEXT.md`

Put the confirmed table under this heading as it is. Stage 0 (resume) looks for this heading — if it is there, the profile check is not asked again and stage 2 resumes (answered modules are judged by their files in `docs/adr/`).

```
## Project profile

| Row | yes/no | Reason |
|---|---|---|
| P1 | yes | earn and spend points |
| P2 | no | no signal |
| P3 | yes | public API readable without login |
| P4 | no | no signal |
| P5 | yes | Korean · English |
| P6 | no | one app |
| P7 | no | no signal |
| P8 | yes | a project of several weeks |
| P9 | no | no signal |
```

Write all nine rows P1–P9, and put only `yes` or `no` in the second column (the check reads it). If a table has no P9 row, read it as no (the one-line note in the SKILL.md stage 0 report).
