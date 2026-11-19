Feature: The site answers and its accounts work
  As the owner of the learning site
  I want the login page, each default account and the test course to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-moodle-cli.sh --add-users); a scenario logs in by a
  # handle of the users registry in cucumber.js, so no password is written here. The course is the test
  # course of a site built with --test-course.

  @critical
  Scenario: A visitor is sent to the login form
    Given I am an anonymous user
    When I go to "/my/"
    Then I should see the login form

  @critical
  Scenario Outline: The <account> account logs in
    Given I am a logged in user with the "<account>" user
    Then I should be logged in as "<account>"

    Examples:
      | account       |
      | administrator |
      | manager       |
      | teacher       |
      | student       |
      | student2      |

  Scenario: A wrong password is refused
    Given I am an anonymous user
    When I log in with the username "student" and the password "wrong-password"
    Then I should see the error message "Your login info may be incorrect. Please try again."
    And I should not be logged in

  Scenario: The student finds the test course and its activities
    Given I am a logged in user with the "student" user
    When I open the course "Software Testing 101"
    Then I should be on the course page
    And the section "Getting started" should list the activity "Testing diary"
    And the activity "Testing diary" should require "Make a submission"

  Scenario: An account in no course is shown the enrolment options
    Given I am a logged in user with the "student2" user
    When I open the course "Software Testing 101"
    Then I should see the enrolment options of the course

  Scenario: Logging out ends the session
    Given I am a logged in user with the "teacher" user
    When I log out
    Then I should see the login form
