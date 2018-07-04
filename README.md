![commercetools logo](https://cdn.rawgit.com/commercetools/press-kit/master/PNG/72DPI/CT%20logo%20horizontal%20RGB%2072dpi.png)

# Node.js Product CSV sync

[![NPM](https://nodei.co/npm/sphere-node-product-csv-sync.png?downloads=true)](https://www.npmjs.org/package/sphere-node-product-csv-sync)

[![Build Status](https://travis-ci.org/sphereio/sphere-node-product-csv-sync.png?branch=master)](https://travis-ci.org/sphereio/sphere-node-product-csv-sync) [![NPM version](https://badge.fury.io/js/sphere-node-product-csv-sync.png)](http://badge.fury.io/js/sphere-node-product-csv-sync) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-node-product-csv-sync/badge.png)](https://coveralls.io/r/sphereio/sphere-node-product-csv-sync) [![Dependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync) [![devDependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync#info=devDependencies)

This component allows you to import, update and export commercetools Products via CSV.
Further you can change the publish state of products.

# Setup

Install `sphere-node-product-csv-sync` module as a global module:
```bash
npm install sphere-node-product-csv-sync --global
```
From now you can use the `product-csv-sync` command with parameters specified below. 

## General Usage

This tool uses sub commands for the various task. Please refer to the usage of the concrete action:
- [import](#import)
- [export](#export)
- [template](#template)
- [state](#product-state)

General command line options can be seen by simply executing the command `node lib/run`.
```
./bin/product-csv-sync
  Usage: product-csv-sync [globals] [sub-command] [options]

  Commands:

    import [options]
       Import your products from CSV into your SPHERE.IO project.

    state [options]
       Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.

    export [options]
       Export your products from your SPHERE.IO project to CSV using.

    template [options]
       Create a template for a product type of your SPHERE.IO project.


  Options:

    -h, --help                       output usage information
    -V, --version                    output the version number
    -p, --projectKey <key>           your SPHERE.IO project-key
    -i, --clientId <id>              your OAuth client id for the SPHERE.IO API
    -s, --clientSecret <secret>      your OAuth client secret for the SPHERE.IO API
    --sphereHost <host>              SPHERE.IO API host to connect to
    --sphereAuthHost <host>          SPHERE.IO OAuth host to connect to
    --timeout [millis]               set timeout for requests (default is 300000)
    --verbose                        give more feedback during action
    --debug                          give as many feedback as possible
```

For all sub command specific options please call `./bin/product-csv-sync <sub command> --help`.


## Import

The import command allows to create new products with their variants as well to update existing products and their variants.
During update it is possible to concentrate only on those attributes that should be updated.
This means that the CSV may contain only those columns that contain changed values.

**NOTE:** When importing [LocalizedString](http://dev.commercetools.com/http-api-types.html#localizedstring) fields (eg. name, description, etc.), all languages have to be provided during the import or the missing ones will be deleted.

### Usage

```
./bin/product-csv-sync import

  Usage: import --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>

  Options:

    -h, --help                                 Output usage information.
    -c, --csv <file>                           CSV file containing products to import.
    -z, --zip <file>                           ZIP archive containing multiple product files to import.
    -l, --language [lang]                      Default language to using during import (for slug generation, category linking etc. - default is en).
    --csvDelimiter [delim]                     CSV Delimiter that separates the cells (default is comma - ",").
    --multiValueDelimiter [delim]              Delimiter to separate values inside of a cell (default is semicolon - ";").
    --customAttributesForCreationOnly <items>  List of comma-separated attributes to use when creating products (ignore when updating).
    --continueOnProblems                       When a product does not validate on the server side (400er response), ignore it and continue with the next products.
    --suppressMissingHeaderWarning             Do not show which headers are missing per produt type.
    --allowRemovalOfVariants                   If given variants will be removed if there is no corresponding row in the CSV. Otherwise they are not touched.
    --mergeCategoryOrderHints                  Merge category order hints instead of replacing them with value readed from an import file.
    --publish                                  When given, all changes will be published immediately.
    --updatesOnly                              Won't create any new products, only updates existing.
    --dryRun                                   Will list all action that would be triggered, but will not POST them to SPHERE.IO.
    -m, --matchBy [value]                      Product attribute name which will be used to match products. Possible values: id, slug, sku, <custom_attribute_name>. Default: id. Localized attribute types are not supported for <custom_attribute_name> option.
```

### CSV Format

#### Base attributes

To create or update products you need 2 columns.
You always need the `productType`. Further you need either `variantId` or `sku` to identify the specific variant.

You can define the `productType` via id or name (as long as it is unique).
Another base attributes which can be specified are `key` and `variantKey`.

#### Variants

Variants are defined by leaving the `productType` cell empty:
```
productType,name,variantId,variantKey,myAttribute
typeName,myProduct,1,,value
,,2,variantKey2,other value
,,3,variantKey3,val
otherType,nextProduct,1,,foo
,,2,variantKey4,bar
```
The CSV above contains:
```
row 0: header
row 1: product with master variant
row 2: 2nd variant of product in row 1
row 3: 3rd variant of product in row 1
row 4: product with master variant
row 5: 2nd variant of product in row 4
```

Non required product attributes
- slug
- state
- metaTitle
- metaDescription
- metaKeywords

> The slug is actually required by SPHERE.IO, but will be generated for the given default language out of the `name` column, when no slug information given.

Non required variant attributes
- sku

#### Localized attributes

The following product attributes can be localized:
- name
- description
- slug
- metaTitle
- metaDescription
- metaKeywords
- searchKeywords

> Further any custom attribute of type `ltext` can be filled with several language values.

Using the command line option `--language`, you can define in which language the values should be imported.

> Using the `--language` option you can define only a single language

Multiple languages can be imported by defining for each language an own column with the following schema:
```
productType,key,name.en,name.de,description.en,description.de,slug.en,slug.de
myType,productKey,my Product,mein Produkt,foo bar,bla bal,my-product,mein-product
```

The pattern for the language header is:
`<attribute name>.<language>`

##### Update of localized attributes

When you want to update a localized attribute, you have to provide all languages of that particular attribute in the CSV file.
Otherwise the language that isn't provided will be removed.

#### Set attributes

If you have an attribute of type `set`, you can define multiple values within the same cell separating them with `;`:
```
productType,...,colors
myType,...,green;red;black
```
The example above will set the value of the `colors` attribute to `[ 'green', 'red', 'black' ]`

#### SameForAll constrainted attributes

To not DRY (don't repeat yourself) when working with attributes that are constrained with `SameForAll`,
you simply have to define the value for all variants on the masterVariant.
```
productType,sku,mySameForAllAttribute
myType,123,thisIsTheValueForAllVariants
,234,
,345,thisDifferentValueWillBeIgnored
```

> Please note, that values for those attributes on the variant rows are completely ignored


#### Product state

In the `state` column, you can define the state of a product. This column must contain the [state](https://docs.commercetools.com/http-api-projects-states.html#state) key. **Unlike the state command above, this state is used for [state transitions](https://docs.commercetools.com/http-api-projects-products.html#transition-state)**

In order to transition the state of a product, simply set the state key in the `state` column to the next state.

#### Tax Category

Just provide the name of the tax category in the `tax` column.

#### Categories

In the `categories` column you can define a list of categories the product should be categorized in separated by `;`.

The tool supports 3 different ways to reference a category. The match works on the following order:
- externalId
- named path
- name

The following example contains 3 categories defined by their named path. The path starts at the root level and all segments are separated with `>`.
```
Root>Category>SameSubCategory;Root2;Root>Category2>SameSubCategory
```
Using the full path of the category name allows you to link to leaf categories with same names but different bread crumb.

> You can also just use the category name as long as it is unqiue within the whole category tree.

#### Prices

In the `prices` column you can define a list of prices for each variant separated by `;`:
```
CH-EUR 999 B2B;EUR 899|745;USD 19900 #retailerA;DE-EUR 1000 B2C#wareHouse1;GB-GBP 999$2001-09-11T14:00:00.000Z~2015-10-12T14:00:00.000Z
```
The pattern for one price is:
`<country>-<currenyCode> <centAmount>|<discountedCentAmount> <customerGroupName>#<channelKey>$<validFrom>~<validUntil>`

Date values `validFrom` and `validUntils` has to be in [ISO 8601 format](http://dev.commercetools.com/http-api-types.html#datetime).

>For the geeks: Have [a look at the regular expression](https://github.com/sphereio/sphere-node-product-csv-sync/blob/e8329dc6a74a560c57a8ab1842decceb42583c0d/src/coffee/constants.coffee#L33) that parses the prices.

mandatory:
- currenyCode
- centAmount

optional:
- country
- customerGroupName
- channelKey
- centAmount for of discounted price (only for export)
- validFrom
- validUntil

#### Numbers

Natural numbers are supported. Negative numbers are prepended with a minus (e.g. `-7`).

> Please note that the there is no space allowed between the minus symbol and the digit

#### Images

In the `images` column you can define a list of urls for each variant separated by `;`:
```
https://example.com/image.jpg;http://www.example.com/picture.bmp
```

> In general we recommend to import images without the protocol like `//example.com/image.png`

#### SEO Attributes

The current implementation allows the set the SEO attributes only if all three SEO attributes are present.
- metaTitle
- metaDescription
- metaKeywords


#### Search Keywords
You can import [Search Keywords](http://dev.commercetools.com/http-api-projects-products.html#search-keywords) that enables to use the Search Suggestion Feature. You can define a list of keywords for each language separated by `;`:

```
searchKeywords,searchKeywords.fr-BE,searchKeywords.de
London;Bristol;Manchester,Liège;Bruxelles;Anvers,Berlin;Köln;München
```


At the moment this importer only supports the default tokenizer, which means each of the semicolon-separated strings will be treated as a whole token. Therefore you have to separate everything that you want to see as a separate token into one entry delimited by semicolon.

#### Category Order Hints

In the `categoryOrderHints` column you can define a list of category order hints for each category that the product belongs to separated by `;`:
```
e8a19675-82af-4c00-98e6-fa9a020b1c51:0.4;myCategoriesName:0.9;myExternalCategoryId:0.2
```
The pattern a category order hint is as follows:
```
<category-ref>:<order-hint>
```
Note:
- `<category-ref>` must be a valid ID referencing an existing category that the product is assigned to. You can reference the category using its `id`, `name` or `externalId`.
- `<order-hint>` has to be a String that is representing a decimal value that is > 0.0 and < 1.0 (0 < orderHint < 1)

#### Publishing

Products with `publish` column set to `true` will be published right after the create/update request is finished. If there are multiple variants of the same product, changes will be published if at least one variant has `publish` set to `true`. Example CSV:
```csv
productType,variantId,sku,name,slug,publish
myType,1,sku,productName,productSlug,true
```

This will create new product and publish it afterward.

## Product State

This sub command allows you to publish/unpublish or delete as set of (or all) products with a single call.

### Usage

```
./bin/product-csv-sync state --help

  Usage: state --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>

  Options:

    -h, --help                             output usage information
    --changeTo <publish,unpublish,delete>  publish unpublished products / unpublish published products / delete unpublished products
    --csv <file>                           processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.
    --continueOnProblems                   When a there is a problem on changing a product's state (400er response), ignore it and continue with the next products
```

#### CSV format

To change the state of only a subset of products you have to provide a list to identify them via a CSV file.

There are currently two ways to identify products:
- id
- sku

An example for sku may look like this:
```
sku
W1234
M2345
M3456
```

> Please note that you always delete products not variants!


## Template

Using this sub command, you can generate a CSV template (does only contain the header row)
for product types. With `--all` a combined template for all product types will be generated.
If you leave this options out, you will be ask for which product type to generate the template.

### Usage

```
./bin/product-csv-sync template --help

  Usage: template --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>

  Options:

    -h, --help                   output usage information
    -o, --out <file>             Path to the file the exporter will write the resulting CSV in
    -l, --languages [lang,lang]  List of languages to use for template (default is [en])
    --outputDelimiter <delimiter> Delimiter used to separate cells in output file | default: ,
    --all                        Generates one template for all product types - if not given you will be ask which product type to use
```


## Export

The export action dumps products to a CSV file. The CSV file may then later be used as input for the import action.

### CSV Export Template

An export template defines the content of the resulting export CSV file, by listing wanted product attribute names as header row. The header column values will be parsed and the resulting export CSV file will contain corresponding attribute values of the exported products.

```
# only productType.name, the variant id and localized name (english) will be exported
productType,name.en,variantId
```

> Please see section [template](https://github.com/sphereio/sphere-node-product-csv-sync/tree/master/data) on how to generate a template.

### Usage

```
./bin/product-csv-sync export

  Usage: export --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>

  Options:

    -h, --help                    output usage information
    -t, --template <file>         CSV file containing your header that defines what you want to export
    -o, --out <file>              Path to the file the exporter will write the resulting CSV in
    -x, --xlsx                    Export in XLSX format
    -f, --fullExport              Do a full export. Use --out parameter to specify where to save zip archive with exported files
    -q, --queryString <query>     Query string to specify the sub-set of products to export
    -l, --language [lang]         Language used on export for localised attributes (except lenums) and category names (default is en)
    --queryEncoded                Whether the given query string is already encoded or not
    --current                     Will export current product version instead of staged one
    --fillAllRows                 When given product attributes like name will be added to each variant row.
    --categoryBy                  Define which identifier should be used for the categories column - options 'namedPath'(default), 'slug' and 'externalId'.
    --categoryOrderHintBy         Define which identifier should be used for the categoryOrderHints column - options 'categoryId'(default), 'id' or 'externalId'.
    --filterVariantsByAttributes  Query string to filter variants of products
    --filterPrices  Query string to filter prices of variants
    --templateDelimiter <delimiter> Delimiter used in template | default: ,
    --outputDelimiter <delimiter>   Delimiter used to separate cells in output file | default: ,
    -e, --encoding [encoding]     Encoding used when saving data to output file | default: utf8

```

#### Full export

You can export products without the need to provide products template. For this option pass the `--fullExport` flag together with the `--out` parameter containing the filePath where the zip archive with the exported products should be saved.

##### Example

```
node lib/run.js export --projectKey <project_key> --clientId <client_id> --clientSecret <client_secret> --fullExport --out products.zip
```

#### Export certain products only

You can define the subset of products to export via the `queryString` parameter, which corresponds of the `where` predicate of the HTTP API.

> Please refer to the [API documentation of SPHERE.IO](http://dev.sphere.io/http-api.html#predicates) for further information regarding the predicates.


##### Example

Query first 10 products of a specific product type
```
limit=10&where=productType(id%3D%2224da8abf-7be6-4b27-9ce6-69ee4b026513%22)
# decoded: limit=0&where=productType(id="24da8abf-7be6-4b27-9ce6-69ee4b026513")
```

#### Export of Localized Enum Labels and Set of Localized Enum Labels

You can export the values of Lenum Labels and Set of Lenum labels by specifying the locale of the labels you want to export. If you don't specify a locale, the key of the lenum will be exported.

> Please refer to the [API documentation of SPHERE.IO](http://dev.sphere.io/http-api-projects-productTypes.html#localizable-enum-type) for further information regarding lenum data types.

The labels of localized enums can not be imported - instead they need to be managed in the ProductType metadata.

##### Example

Export the key and the english label of the attributes `myLenum` and `mySetOfLenum`.

```csv
variantId,myLenum,myLenum.en,mySetOfLenum,mySetOfLenum.en
1,myLenumKey,My English Lenum Label,mySetOfLenumKey1;mySetOfLenumKey2,My Set of Lenum English Label 1, my Set of Lenum English Label 2
```

#### Export with different encoding

Default encoding used during export is `utf8`. With `--encoding` parameter there can be specified one of encodings listed [here](https://github.com/ashtuchkin/iconv-lite/wiki/Supported-Encodings).
Most commonly used are:
 * Node.js Native encodings: utf8, ucs2 / utf16le, ascii, binary, base64, hex
 * Unicode: UTF-16BE, UTF-16 (with BOM)
 * Single-byte:
   * Windows codepages: 874, 1250-1258 (aliases: cpXXX, winXXX, windowsXXX)
   * ISO codepages: ISO-8859-1 - ISO-8859-16

##### Example

```csv
node lib/run.js export --projectKey <project_key> --clientId <client_id> --clientSecret <client_secret> --template path/to/template.csv --out products.zip -e "win1250"
```


## General CSV notes

Please make sure to read the following lines use valid CSV format.

### Multi line text cells
Make sure you enclose multiline cell values properly in quotes

wrong:
```csv
header1,header2,header3
value 1,value 2,this is a
multiline value
```
right:
```csv
header1,header2,header3
value1,value2,"this is a
multiline value"
```

### Text cells with quotes
If your cell value contains a quote, make sure to escape the quote with a two quotes (change `"` to `""`). Also the whole cell value should be enclosed in quotes in this case.

wrong:
```csv
header1,header2,header3
value 1,value 2,this is "value 3"
```

right:
```csv
header1,header2,header3
value 1,value 2,"this is ""value 3"""
```
