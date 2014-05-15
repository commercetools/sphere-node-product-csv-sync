Feature: Show common information for tooling

  Scenario: Show help when run without arguments
    When I run `node ../../lib/run`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage
    """