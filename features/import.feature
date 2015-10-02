Feature: Import products

  Scenario: Can't find product type
    Given a file named "i.csv" with:
    """
    productType,variantId
    foo,1
    """
    When I run `../../bin/product-csv-sync import --projectKey nicola --csv i.csv`
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
    When I run `../../bin/product-csv-sync import --projectKey nicola --csvDelimiter ';' --csv i.csv`
    Then the exit status should be 1
    And the output should contain:
    """
    [ 'Your selected delimiter clash with each other: {"csvDelimiter":";","csvQuote":"\\"","language":".","multiValue":";","categoryChildren":">"}' ]
    """

  Scenario: Import/update and remove a product
    When I run `../../bin/product-csv-sync state --projectKey nicola --changeTo delete` interactively
    And I type "yes"

    Given a file named "i.csv" with:
    """
    productType,variantId,name,sku
    ImpEx with all types,1,myProduct,12345
    """
    When I run `../../bin/product-csv-sync import --projectKey nicola --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] New product created.' ]
    """

    When I run `../../bin/product-csv-sync import --projectKey nicola --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product update not necessary.' ]
    """

    Given a file named "u.csv" with:
    """
    productType,variantId,name,sku
    ImpEx with all types,1,myProductCHANGED,12345
    """
    When I run `../../bin/product-csv-sync import --projectKey nicola --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    When I run `../../bin/product-csv-sync state --projectKey nicola --changeTo delete` interactively
    And I type "yes"
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 0] Product deleted.' ]
    """

  Scenario: Match products

    Given a file named "i.csv" with:
    """
    id,productType,slug.en,variantId,name,sku,attr-text-n
    0912,ImpEx with all types,slug_1,1,myProduct,12345,key_1
    """
    When I run `../../bin/product-csv-sync import --projectKey nicola --csv i.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] New product created.' ]
    """

    Given a file named "u.csv" with:
    """
    id,productType,slug.en,variantId,name,sku,attr-text-n
    0912,ImpEx with all types,slug_1,1,myProduct_mb_id,12345,key_1
    """
    When I run `../../bin/product-csv-sync import --projectKey nicola --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    Given a file named "u.csv" with:
    """
    id,productType,slug.en,variantId,name,sku,attr-text-n
    0912,ImpEx with all types,slug_1,1,myProduct_mb_slug,12345,key_1
    """
    When I run `../../bin/product-csv-sync import -m slug --projectKey nicola --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    Given a file named "u.csv" with:
    """
    id,productType,slug.en,variantId,name,sku,attr-text-n
    0912,ImpEx with all types,slug_1,1,myProduct_mb_sku,12345,key_1
    """
    When I run `../../bin/product-csv-sync import -m sku --projectKey nicola --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    Given a file named "u.csv" with:
    """
    id,productType,slug.en,variantId,name,sku,attr-text-n
    0912,ImpEx with all types,slug_1,1,myProduct_mb_ca,12345,key_1
    """
    When I run `../../bin/product-csv-sync import -m attr-text-n --projectKey nicola --csv u.csv`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    When I run `../../bin/product-csv-sync state --projectKey nicola --changeTo delete` interactively
    And I type "yes"
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 0] Product deleted.' ]
    """
