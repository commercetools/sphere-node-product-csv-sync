Feature: Import products

  Scenario: Can't find product type
    Given a file named "i.csv" with:
    """
    id,productType,variantId
    abcd,foo,1
    """
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy sku`
    Then the exit status should be 1
    And the output should contain:
    """
    CSV file with 2 row(s) loaded.
    [ '[row 2] Can\'t find product type for \'foo\'' ]
    """

  Scenario: Show message when delimiter selection clashes
    Given a file named "i.csv" with:
    """
    productType,variantId,id
    """
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csvDelimiter ';' --csv i.csv --matchBy sku`
    Then the exit status should be 1
    And the output should contain:
    """
    [ 'Your selected delimiter clash with each other: {"csvDelimiter":";","csvQuote":"\\"","language":".","multiValue":";","categoryChildren":">"}' ]
    """

  Scenario: Import/update and remove a product
    When I run `../../bin/product-csv-sync state --projectKey sphere-node-product-csv-sync-94 --changeTo delete` interactively
    And I type "yes"

    Given a file named "i.csv" with:
    """
    productType,variantId,name,sku
    ImpEx with all types,1,myProduct,12345
    """
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy sku`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] New product created.' ]
    """

    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy sku`
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
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv u.csv --matchBy sku`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    When I run `../../bin/product-csv-sync state --projectKey sphere-node-product-csv-sync-94 --changeTo delete` interactively
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
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy sku`
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
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv u.csv --matchBy sku`
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
    When I run `../../bin/product-csv-sync import -m slug --projectKey sphere-node-product-csv-sync-94 --csv u.csv --matchBy sku`
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
    When I run `../../bin/product-csv-sync import -m sku --projectKey sphere-node-product-csv-sync-94 --csv u.csv --matchBy sku`
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
    When I run `../../bin/product-csv-sync import -m attr-text-n --projectKey sphere-node-product-csv-sync-94 --csv u.csv --matchBy sku`
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 2] Product updated.' ]
    """

    When I run `../../bin/product-csv-sync state --projectKey sphere-node-product-csv-sync-94 --changeTo delete` interactively
    And I type "yes"
    Then the exit status should be 0
    And the output should contain:
    """
    [ '[row 0] Product deleted.' ]
    """

    Scenario: Batch import

      Given a file named "i.csv" with:
      """
      productType,slug.en,name,variantId,sku,attr-text-n
      ImpEx with all types,slug_1,myProduct,1,1,key_1
      ,,,2,1_1,key_1_1
      ,,,2,1_2,key_1_2
      ImpEx with all types,slug_2,myProduct,1,2,key_1
      ,,,2,2_1,key_2_1
      ,,,2,2_2,key_2_2
      ImpEx with all types,slug_3,myProduct,1,3,key_1
      ImpEx with all types,slug_4,myProduct,1,4,key_1
      ImpEx with all types,slug_5,myProduct,1,5,key_1
      ImpEx with all types,slug_6,myProduct,1,6,key_1
      ImpEx with all types,slug_7,myProduct,1,7,key_1
      ImpEx with all types,slug_8,myProduct,1,8,key_1
      ImpEx with all types,slug_9,myProduct,1,9,key_1
      ImpEx with all types,slug_10,myProduct,1,10,key_1
      ImpEx with all types,slug_11,myProduct,1,11,key_1
      ImpEx with all types,slug_12,myProduct,1,12,key_1
      ImpEx with all types,slug_13,myProduct,1,13,key_1
      ImpEx with all types,slug_14,myProduct,1,14,key_1
      ImpEx with all types,slug_15,myProduct,1,15,key_1
      ImpEx with all types,slug_16,myProduct,1,16,key_1
      ImpEx with all types,slug_17,myProduct,1,17,key_1
      ImpEx with all types,slug_18,myProduct,1,18,key_1
      ImpEx with all types,slug_19,myProduct,1,19,key_1
      ImpEx with all types,slug_20,myProduct,1,20,key_1
      ImpEx with all types,slug_21,myProduct,1,21,key_1
      ,,,2,21_1,key_21_1
      ,,,2,21_2,key_21_2
      """
      When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy slug`
      Then the exit status should be 0
      And the output should contain:
      """
      [ '[row 2] New product created.',
        '[row 5] New product created.',
        '[row 8] New product created.',
        '[row 9] New product created.',
        '[row 10] New product created.',
        '[row 11] New product created.',
        '[row 12] New product created.',
        '[row 13] New product created.',
        '[row 14] New product created.',
        '[row 15] New product created.',
        '[row 16] New product created.',
        '[row 17] New product created.',
        '[row 18] New product created.',
        '[row 19] New product created.',
        '[row 20] New product created.',
        '[row 21] New product created.',
        '[row 22] New product created.',
        '[row 23] New product created.',
        '[row 24] New product created.',
        '[row 25] New product created.',
        '[row 26] New product created.' ]
      """

      When I run `../../bin/product-csv-sync state --projectKey sphere-node-product-csv-sync-94 --changeTo delete` interactively
      And I type "yes"
      Then the exit status should be 0
      And the output should contain:
      """
      [ '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.',
        '[row 0] Product deleted.' ]
      """
