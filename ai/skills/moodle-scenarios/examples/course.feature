Feature: The course page
  The sections of the test course, the activities of each, and what completes them.

  Scenario: The student sees the sections and their activities
    Given I am a logged in user with the "student" user
    When I open the course "Software Testing 101"
    Then I should be on the course page
    And the course sections should be:
      | General         |
      | Getting started |
      | Practice        |
      | Wrap-up         |
    And the section "Getting started" should list the activity "Testing diary"
    And the section "Practice" should list the activity "Basics quiz"
    And the activity "Testing diary" should require "Make a submission"

  Scenario: An activity is marked as done by hand, and undone
    Given I am a logged in user with the "student" user
    And I open the course "Software Testing 101"
    When I mark the activity "Class discussion" as done
    Then I should see the message "Class discussion marked as done."
    And the activity "Class discussion" should be marked as done
    When I mark the activity "Class discussion" as not done
    Then the activity "Class discussion" should not be marked as done
