# Import
- on update handle changes of
  * categories
  * taxes
- allow to define if match is against staged or published existing products (current it's staged)

### Command line options
- allow to overwrite delimiters
- add option to "validateOnly"
- add option to re-index after import

### Ideas
- allow to define publish state as column
- allow to define slug of category instead of id or tree path

### Questions
- How to handle attributes that are called like base attributes?
  (eg. name, description, productType, slug, etc.) - maybe some prefix like "."
- Do we have negative prices?

# Export
- support export of
  * product type
  * taxes
  * prices
  * sku
  * variantId
  * categories
  * money-typed attributes

### Command line options
- select wheter to use staged or published
- allow to provide product type

### Ideas
- generate CSV template for one product type
