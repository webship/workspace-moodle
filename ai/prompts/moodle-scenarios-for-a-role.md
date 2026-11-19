Write and run webship-js scenarios for what one role may do on a Moodle learning site.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write scenarios for what the <teacher|student|manager> account may and may not do on this site, and run them
# ~/workspace/<folder>/<site> · https://<site>.ddev.site · container-based (DDEV by default)
# the phrases are in the moodle-scenarios skill; the moodle-tester agent is the one to hand this work over to
# look at the site first: in the Playwright MCP browser, in a tab of your own, do each thing as that account by hand once before writing its scenario
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

What to cover:
<what this role does in the course and on the site, and what it may not open, one per line>

Read the installed steps first:
grep -hE '^(Given|When|Then)\(' node_modules/@webship-js/moodle-steps/tests/step-definitions/*.steps.js

Write one feature in tests/features/<role>.feature, from phrases that exist: a table of who may open each page
(Then the access to "<page>" should be:), and a scenario per task for the account of the role.
Log in by the handle of the users registry (administrator, manager, teacher, student, student2):
no password in the feature, no account created by a scenario, no platform name in a step phrase,
and what a scenario changes it changes back (a submission removed, a grade cleared, attempts and posts deleted).

Then, from the sites folder (cd ..):
bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<role>.feature
bash cmd-tools-testing.sh <site> --run --path tests/features/<role>.feature

A failing scenario is a result: tell me what the site did, do not loosen the scenario.
When you are done: the scenarios, the result of the run, and any step you could not find in the pack
"""
```
