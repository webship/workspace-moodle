Feature: Enrolment
  The teacher enrols an account and unenrols it again; an account enrols itself with the key.

  Scenario: The teacher enrols an account, then unenrols it
    Given I am a logged in user with the "teacher" user
    And I open the course "Software Testing 101"
    When I enrol "student2" in the course as "Student"
    Then "student2" should be enrolled in the course
    When I unenrol "student2" from the course
    Then "student2" should not be enrolled in the course

  Scenario: An account enrols itself with the key, then leaves
    Given I am a logged in user with the "student2" user
    When I enrol myself in the course "Software Testing 101" with the key "TEST101-key"
    Then I should be on the course page
    When I unenrol myself from the course "Software Testing 101"
    Then my courses should not list "Software Testing 101"
