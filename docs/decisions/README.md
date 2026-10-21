# Architecture decision records

One Markdown file per decision, in [MADR 4.0.0](https://adr.github.io/madr/) form:
metadata in YAML front matter, then Context and Problem Statement, Considered Options
and Decision Outcome, with Decision Drivers and Consequences when they add meaning. New
records start from [`adr-template.md`](adr-template.md).

[`../explanation/design-decisions.md`](../explanation/design-decisions.md) describes
the design as it stands; this directory is the log of how it got there. A record that
changes a documented default also updates that page.

| ADR | Title | Status |
| --- | --- | --- |

## When to write one

Write a record for a decision that changes architecture, security posture, the
operational model, a technology choice, an integration pattern, a data flow, the
deployment model, an ownership boundary or a significant trade-off. Do not write one
for refactoring, bug fixes, dependency updates or changes that implement a recorded
decision.

## How to write one

1. Copy `adr-template.md` to `NNNN-title-with-dashes.md`, where `NNNN` is the next
   number in this directory. Never reuse or renumber.
2. Fill in the sections. Keep Decision Drivers and Consequences only when they say
   something. Aim for one page, in plain language.
3. Set `status: "proposed"` and today's date, link the pull request under a
   `## More Information` heading, and add a row to the table above.
4. A human reviewer sets `status: "accepted"` and updates the date. A record drafted
   by an agent stays proposed until then.

## Changing a decision

A significant change gets a new record that names the old one. Set the old record's
status to `superseded by ADR-NNNN`, update its date and its index row, and leave the
rest as written. A decision that no longer applies is marked `deprecated`; one
considered and not taken is `rejected`.

## Review

Copilot code review follows
[`.github/instructions/adr-review.instructions.md`](../../.github/instructions/adr-review.instructions.md)
on every pull request it reviews. It comments when a change needs a record that the pull
request does not add, and when a record differs from this page or the template. It only
comments: the author writes the record, and a human reviewer accepts it. Code review
does not follow links, so that file restates these rules in short form; when this page
changes, change it in the same pull request.
