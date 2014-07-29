Feature: Import products

  Scenario: Can't find product type
    Given a file named "i.csv" with:
    """
    productType,variantId
    foo,1
    """
    When I run `node ../../lib/run --projectKey import-101-64 import --csv i.csv`
    Then the exit status should be 1
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    [ '[row 2] Can\'t find product type for \'foo\'' ]
    """

  Scenario: Show message when delimiter selection clashes
    Given a file named "i.csv" with:
    """
    productType,variantId
    """
    When I run `../../bin/product-csv-sync --projectKey import-101-64 import --csvDelimiter ';' --csv i.csv`
    Then the exit status should be 1
    And the output should contain:
    """
    [ 'Your selected delimiter clash with each other: {"csvDelimiter":";","csvQuote":"\"","language":".","multiValue":";","categoryChildren":">"}' ]
    """

  @wip
  Scenario: Import/update and remove a product
    Given a file named "i.csv" with:
    """
    productType,variantId,name,sku
    theType,1,myProduct,12345
    """
    When I run `node ../../lib/run --projectKey sphere-node-product-csv-sync-94 import --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    Mapping 1 product(s) ...
    Mapping done. Fetching existing product(s) ...
    Comparing against 0 existing product(s) ...
    [ '[row 2] New product created.' ]
    """

    When I run `node ../../lib/run --projectKey sphere-node-product-csv-sync-94 import --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    Mapping 1 product(s) ...
    Mapping done. Fetching existing product(s) ...
    Comparing against 1 existing product(s) ...
    [ '[row 2] Product update not necessary.' ]
    """

    Given a file named "u.csv" with:
    """
    productType,variantId,name,sku
    theType,1,myProductCHANGED,12345
    """
    When I run `node ../../lib/run --projectKey sphere-node-product-csv-sync-94 import --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    Mapping 1 product(s) ...
    Mapping done. Fetching existing product(s) ...
    Comparing against 1 existing product(s) ...
    [ '[row 2] Product updated.' ]
    """

    Given a file named "d.csv" with:
    """
    sku
    12345
    """
    When I run `node ../../lib/run --projectKey sphere-node-product-csv-sync-94 state --changeTo delete --csv d.csv` interactively
    And I type "yes"
    Then the exit status should be 0
    And the output should contain:
    """
    Found 1 product(s) ...
    Filtered 1 product(s).
    Deleting 1 product(s) ...
    [ '[row 0] Product deleted.' ]
    """
