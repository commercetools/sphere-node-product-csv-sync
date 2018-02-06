Feature: Export products

  Scenario: Import some products first
    Given a file named "i.csv" with:
    """
    productType,name,key,variantId,sku
    ImpEx with all types,Product 1,product-key-1,1,sku-1-123
    ImpEx with all types,Product 2,product-key-2,1,sku-2-123
    ImpEx with all types,Product 3,product-key-3,1,0123
    """
    When I run `../../bin/product-csv-sync import --projectKey sphere-node-product-csv-sync-94 --csv i.csv --matchBy sku`
    Then the exit status should be 0
    And the output should contain:
    """
    Finished processing 3 product(s)
    """

  @wip
  Scenario: Export products with --fillAllRows
    Given a file named "t.csv" with:
    """
    productType,name,sku
    """
    When I run `../../bin/product-csv-sync export --projectKey sphere-node-product-csv-sync-94 --template 't.csv' --out 'exported.csv' --fillAllRows`
    Then the exit status should be 0
    And the output should contain:
    """
    Fetched 3 product(s)
    """
    Then a file named "exported.csv" should exist
    And the file "exported.csv" should match /^productType,name,sku$/
    And the file "exported.csv" should match /^ImpEx with all types,Product 3,0123$/
    And the file "exported.csv" should match /^ImpEx with all types,Product 3,2345$/

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

  @wip
  Scenario: Export all products
    When I run `../../bin/product-csv-sync export --projectKey sphere-node-product-csv-sync-94 --out 'exported.zip' --fullExport`
    Then the exit status should be 0
    And the output should contain:
    """
    Processing products with productType "ImpEx with all types"
    Fetched 3 product(s).
    Processing products with productType "theType"
    Fetched 0 product(s).
    All productTypes were processed - archiving output folder
    Folder was archived and saved to exported.zip
    Export done.
    """
    Then a file named "exported.zip" should exist
