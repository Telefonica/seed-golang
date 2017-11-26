Feature: Get user
  As a user of the service
  I want to be able to get a user

  Scenario: Get a registered user
    Given a user is registered
    When I get the user
    Then the service replies with status 200
    And the body contains the user information

  Scenario: Get an unregistered user
    Given a user is unregistered
    When I get the user
    Then the service replies with status 404
    And the error is "invalid_request" and the error description is "not found"
