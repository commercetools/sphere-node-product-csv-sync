# Import
- allow to define if match is against staged or published existing products (current it's staged)
- allow to define custom attribute for matching (eg. EAN, externalId etc.)
- allow to define image dimensions
- allow partial updates - only those columns that are defined are compared.

### Command line options
- allow to overwrite delimiters
- add option to "validateOnly"
- add option to re-index after import (new endpoint necessary)

### Ideas
- allow to define publish state as column
- allow to define slug of category instead of id or tree path
- allow to define "delete product" as "action" column
- allow to delete all products
- download existing products in batches

### Questions
- How to handle attributes that are called like base attributes?
  (eg. name, description, productType, slug, etc.) - maybe some prefix like "."

# Export
- support export of
  * categories
  * money-typed attributes
  * image labels
  * image dimensions

### Ideas
- generate CSV template for one product type providing the languages via command line option for the localized strings
