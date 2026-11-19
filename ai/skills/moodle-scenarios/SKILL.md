---
name: moodle-scenarios
description: Write and run webship-js scenarios for a Moodle learning site of the Webship Workspace with the Moodle step pack (`@webship-js/moodle-steps`) — the phrases of the pack by area (the session and the guest access, the Dashboard and My courses, the course page and completion, enrolment and roles, the assignment, the quiz, the forum, the gradebook, messages, notifications and the calendar, the site administration and course management, who may open a page), the handles of the users registry, and the workspace command that runs them in the site's container. Use when asked to "write a scenario for this Moodle site", "test the quiz", "which step is there for the grader report", "add a feature for self enrolment", or when a `.feature` file of a Moodle project is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# moodle-scenarios

Scenarios for a Moodle learning site of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/moodle-steps`](https://github.com/webship/moodle-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the site's container by
the workspace's own command. It comes with the Moodle plugin (`@webship.co/workspace-moodle`), like the
builder (`cmd-moodle-project.sh`), the CLI tool (`cmd-tools-moodle-cli.sh`) and the agents
`moodle-site-builder` and `moodle-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The site | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The release package | `<site>/moodle/` (served from `moodle/public`), its data folder `<site>/moodledata/` |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`) |
| The features | `<site>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<site>/node_modules/@webship-js/moodle-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, the step pack, the users registry and `tests/features/site.feature`, and makes
   sure the default accounts are on the site. It is safe to run again: it adds what is missing and
   keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/moodle-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen: its names, its buttons, its messages, where a refused account
   is sent.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on a site built
with `--add-users` already (`bash cmd-tools-moodle-cli.sh <site> --add-users` writes them again,
with their name, address, password and roles):

| Handle | Account | Its role |
| --- | --- | --- |
| `administrator` | `administrator@example.com` | A site administrator |
| `manager` | `manager@example.com` | The Manager role on the whole site |
| `teacher` | `teacher@example.com` | Teacher (editing) in the test course |
| `student` | `student@example.com` | Student in the test course |
| `student2` | `student2@example.com` | In no course: it enrols itself with the key |

```gherkin
Given I am a logged in user with the "teacher" user
Then I should be logged in as "teacher"
```

## The phrases, by area

Each line is a phrase the pack or webship-js defines, and each one passed on a site built with
`bash cmd-moodle-project.sh <site> --install --add-users --test-course`. Most `should` steps also take
the negative: `should not see`, `should not be`, `should not list`.

### The session

```gherkin
Given I am an anonymous user
Given I am a logged in user with the "student" user
When I log in as "student" with the login form
When I log in with the username "student" and the password "wrong-password"
When I log in as a guest
When I log out
Then I should be logged in
Then I should be logged in as "student"
Then I should be logged in as a guest
Then I should see the login form
```

### Pages, messages and who may open a page

```gherkin
Then I should see the error message "Your login info may be incorrect. Please try again."
Then I should see the success message "Post added."
Then I should see the message "1 enrolled users"
Then I should not see any error message
When I wait for the page to be ready
When I go to my dashboard
When I go to my courses
Then my courses should list "Software Testing 101"
Then the course progress of "Software Testing 101" should be "25%"
Then I should see the block "Timeline"
Then the timeline should list "Testing diary"
Then I should have access to "/course/management.php"
Then I should not have access to "/admin/search.php"
Then the access to "/course/management.php" should be:
  | account       | access  |
  | administrator | allowed |
  | manager       | allowed |
  | student       | denied  |
```

### The course page

```gherkin
When I open the course "Software Testing 101"
Then I should be on the course page
Then I should see the enrolment options of the course
Then the course sections should be:
  | General         |
  | Getting started |
  | Practice        |
  | Wrap-up         |
Then the section "Getting started" should list the activity "Testing diary"
When I open the activity "Course handbook"
Then the activity "Course handbook" should be marked as done
Then the activity "Testing diary" should require "Make a submission"
When I mark the activity "Class discussion" as done
When I mark the activity "Class discussion" as not done
When I go to the "Participants" page of the course
```

### Enrolment and roles

```gherkin
When I enrol "student2" in the course as "Student"
When I unenrol "student2" from the course
Then "student2" should be enrolled in the course
Then "student" should have the role "Student" in the course
When I assign the role "Non-editing teacher" to "student" in the course
When I remove the role "Non-editing teacher" from "student" in the course
When I enrol myself in the course "Software Testing 101" with the key "TEST101-key"
Then enrolling myself in the course "Software Testing 101" with the key "wrong-key" should be refused with "Incorrect enrolment key, please try again"
When I unenrol myself from the course "Software Testing 101"
```

### The assignment, the quiz and the forum

```gherkin
When I submit the text "Found a defect in the login form." for the assignment "Testing diary"
Then the "Submission status" of the assignment "Testing diary" should be "Submitted for grading"
When I grade "student" with "85" for the assignment "Testing diary" with the feedback "Well found."
Then the "Needs grading" count of the assignment "Testing diary" should be "0"
Then my grade for the assignment "Testing diary" should be "85.00 / 100.00"
When I clear the grade of "student" for the assignment "Testing diary"
When I remove my submission for the assignment "Testing diary"
When I start an attempt at the quiz "Basics quiz"
When I answer "True" to the question "Testing can show that defects are present."
When I submit the quiz attempt
Then the "Grade" of the attempt should be "10.00 out of 10.00 (100%)"
Then the question "1" should be marked "Correct"
Then my highest grade at the quiz "Basics quiz" should be "10.00 / 10.00"
When I delete the attempts of "student" at the quiz "Basics quiz"
When I post the discussion "A question" with the message "Why?" in the forum "Class discussion"
When I reply "Because." to the discussion "A question" in the forum "Class discussion"
Then the forum "Class discussion" should list the discussion "A question"
Then the discussion "A question" in the forum "Class discussion" should have the reply "Because." from "teacher"
When I delete the discussion "A question" from the forum "Class discussion"
```

### The gradebook

```gherkin
Then the grader report should show "85.00" for "student" in "Testing diary"
Then my grade for "Testing diary" in the user report should be "85.00"
```

### Messages, notifications and the calendar

```gherkin
When I send the message "Hello" to "teacher"
Then I should have the message "Hello" from "student"
When I delete my conversation with "student"
Then I should have the notification "Welcome to Software Testing 101"
Then I should have the new notification "Assignment submission confirmation - Testing diary"
When I mark all my notifications as read
When I add the event "Study group" to my calendar
Then my calendar should show the event "Study group"
When I delete the event "Study group" from my calendar
Then the upcoming events should list "Testing diary is due"
```

### The site administration

```gherkin
When I search the site administration for "guest login button"
Then the site administration search should find the setting "Guest login button"
Then the setting "Guest login button" should be "Show"
Then the category "Test courses" should list the course "Software Testing 101"
When I create the course "Throwaway course" with the short name "THROW1" in the category "Test courses"
When I delete the course "Throwaway course" from the category "Test courses"
```

`I am an anonymous user`, `I should see "<text>"`, `I go to "<path>"`, `I click the "<name>" button` and
`the response status code should be 200` are webship-js's own steps; its fields, dialogs, cookies,
status codes and accessibility audits are used as they are and never redefined for this platform.

## Traps found on a real site

- **A new 5.x site asks every visitor to log in.** The home page sends a visitor to the login page, so
  a scenario that starts on the home page starts on the login form.
- **My courses is off on a new 5.x site.** `When I go to my courses` lands on the Dashboard, which
  carries the course overview: the steps read the block wherever it is.
- **A password typed too early is lost.** The login page renders its password field again once a
  template arrives; the login steps wait for the page's own work and read the fields back. A custom
  login step must do the same.
- **Toasts close by themselves.** "1 enrolled users", "The changes to the grade and feedback were
  saved": check the message right after the action, before a step that opens another page.
- **Viewing completes for good.** A page completed by viewing it stays completed: assert the progress
  after the view, so it holds on every run.
- **A student cannot delete a post once anybody replied.** The teacher deletes the discussion.
- **Notifications come back.** A notification stays in the menu once read; check for a new one, then
  mark them all as read, so the next run checks a new one again.

## Rules

- **No account is created in a suite.** No account made in a hook, no sign-up that goes through. An
  account the registry does not have is asked for, not made.
- **Never the workspace account.** The site's administrator from the build is not in the registry.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I submit the quiz attempt`, never a phrase that names the
  platform. The same holds for a custom step.
- **What a scenario changes, it changes back** in the same scenario.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<site>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the site did.

## Examples that run

`examples/` holds three features that pass on a site built with
`bash cmd-moodle-project.sh <site> --install --add-users --test-course`, and leave it as they found it.
Copy one into the suite and run it:

- `examples/course.feature`: the course page, its sections and activities, completion.
- `examples/assignment.feature`: a submission handed in, graded and taken back.
- `examples/enrolment.feature`: an account enrolled by the teacher, and self enrolment with the key.

```bash
cp ~/workspace/ai-skills/moodle-scenarios/examples/course.feature ~/workspace/<folder>/<site>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <site> --run --path tests/features/course.feature
```

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Moodle.** Start with `ch10-authentication-authorization.md` (logins, sessions, roles and who
  may open a page), `ch07-waiting-dynamic-content.md` (waiting on the site's own signals, never on a
  clock), `ch26-testing-cms-applications.md` (content, roles and their workflows) and
  `ch21-when-tests-go-bad.md` (flaky, brittle and slow scenarios).
