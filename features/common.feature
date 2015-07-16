Feature: Show common information for tooling

  Scenario: Show general help
    When I run `product-csv-sync`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage: product-csv-sync
    """

  Scenario: Show help when running import subcommand
    When I run `product-csv-sync import`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage: import
    """

  Scenario: Show help when running export subcommand
    When I run `product-csv-sync export`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage: export
    """

  Scenario: Show help when running state subcommand
    When I run `product-csv-sync state`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage: state
    """

  Scenario: Show help when running template subcommand
    When I run `product-csv-sync template`
    Then the exit status should be 0
    And the output should contain:
    """
    Usage: template
    """