Feature: The Moodle plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Moodle builder, each
  AI folder lists the items of its kind the plugin ships, and Settings lists the plugin with
  what it ships.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Moodle"
     When I go to "/settings/plugin/moodle"
     Then I should see "@webship.co/workspace-moodle"
      And I should see "cmd-moodle-project.sh"
      And I should see "moodle-site-builder"

  Scenario: A sites folder offers the Moodle builder
    Given I am on "/dev"
     Then "option[value='cmd-moodle-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=moodle-"
     Then I should see "moodle-site-builder"
      And I should see "moodle-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=moodle-scenarios"
     Then I should see "moodle-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=moodle-test"
     Then I should see "moodle-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=moodle-"
     Then I should see "moodle-build-and-test"
      And I should see "moodle-scenarios-for-a-role"
