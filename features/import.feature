Feature: Import products

  @wip
  Scenario: Simple import
    Given a file named "i.csv" with:
    """
    productType,variantId
    foo,1
    """
    When I run `node ../../lib/run --projectKey import-101-64 import --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    """