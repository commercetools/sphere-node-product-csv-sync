Feature: Show common information for tooling

  Scenario: Show help when running without arguments
    When I run `../../bin/product-csv-sync`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage
    """

  @wip
  Scenario: Show help when running subcommand
    When I run `../../bin/product-csv-sync import`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage
    """