Feature: Export products

  Scenario: Import some products first
    Given a file named "i.csv" with:
    """
    productType,name,variantId,sku
    ImpEx with all types,Product 1,1,sku-1-123
    ImpEx with all types,Product 2,1,sku-2-123
    ImpEx with all types,Product 3,1,0123
    """
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv`
    Then the exit status should be 0

  Scenario: Export products by query
    When I run `../../bin/product-csv-sync export --projectKey sphere-node-product-csv-sync-94 --template '../../data/template_sample.csv' --out '../../data/exported.csv' --queryString 'where=name(en = "Product 1")&staged=true'`
    Then the exit status should be 0
    And the output should contain:
    """
    Fetched 1 product(s)
    """

  Scenario: Export products by query (encoded)
    When I run `../../bin/product-csv-sync export --projectKey sphere-node-product-csv-sync-94 --template '../../data/template_sample.csv' --out '../../data/exported.csv' --queryString 'where=name(en%20%3D%20%22Product%201%22)&staged=true' --queryEncoded`
    Then the exit status should be 0
    And the output should contain:
    """
    Fetched 1 product(s)
    """

  @wip
  Scenario: Export products by search
    When I run `../../bin/product-csv-sync export --projectKey sphere-node-product-csv-sync-94 --template '../../data/template_sample.csv' --out '../../data/exported.csv' --queryString 'text.en=0123&staged=true' --queryType search`
    Then the exit status should be 0
    And the output should contain:
    """
    Fetched 1 product(s)
    """
