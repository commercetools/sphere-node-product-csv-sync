sphere-node-product-csv-sync
============================

SPHERE.IO component to import, update and export products via CSV.

[![Build Status](https://travis-ci.org/sphereio/sphere-node-product-csv-sync.png?branch=master)](https://travis-ci.org/sphereio/sphere-node-product-csv-sync) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-node-product-csv-sync/badge.png)](https://coveralls.io/r/sphereio/sphere-node-product-csv-sync) [![Dependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync) [![devDependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync#info=devDependencies)

# Setup

* install [NodeJS](http://support.sphere.io/knowledgebase/articles/307722-install-nodejs-and-get-a-component-running) (platform for running application)

### From scratch

* install [npm](http://gruntjs.com/getting-started) (NodeJS package manager, bundled with node since version 0.6.3!)
* install [grunt-cli](http://gruntjs.com/getting-started) (automation tool)
*  resolve dependencies using `npm`
```bash
$ npm install
```
* build javascript sources
```bash
$ grunt build
```

### From ZIP

* Just download the ready to use application as [ZIP](https://github.com/sphereio/sphere-node-product-csv-sync/archive/latest.zip)
* Extract the latest.zip with `unzip sphere-node-product-csv-sync-latest.zip`
* Change into the directory `cd sphere-node-product-csv-sync-latest`

## General Usage

This tool uses sub commands for the various task. Please refer to the usage of the concrete action:
- [import](#import)
- [export](#export)
- [template](#template)
- [state](#product-state)
- [groupVariants](#group-variants)

General command line options can be seen by simply executing the command `node lib/run`.
```
node lib/run

  Usage: run [globals] [sub-command] [options]

  Commands:

    import [options]       Import your products from CSV into your SPHERE.IO project.
    state [options]        Allows to publish, unpublish or delete (all) products of your SPHERE.IO project.
    export [options]       Export your products from your SPHERE.IO project to CSV using.
    template [options]     Create a template for a product type of your SPHERE.IO project.
    groupvariants [options]  Allows you to group products with its variant in order to proceed with SPHERE.IOs CSV product format.

  Options:

    -h, --help                   output usage information
    -V, --version                output the version number
    -p, --projectKey <key>       your SPHERE.IO project-key
    -i, --clientId <id>          your OAuth client id for the SPHERE.IO API
    -s, --clientSecret <secret>  your OAuth client secret for the SPHERE.IO API
    --timeout [millis]           Set timeout for requests
    --verbose                    give more feedback during action
    --debug                      give as many feedback as possible
```

For all sub command specific options please call `node lib/run <sub command> --help`.


## Import

### Usage

```
node lib/run import --help

  Usage: import --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --csv <file>

  Options:

    -h, --help             output usage information
    -c, --csv <file>       CSV file containing products to import
    -l, --language [lang]  Default language to using during import
    --continueOnProblems   When a product does not validate on the server side (400er response), ignore it and continue with the next products
    --publish              When given, all changes will be published immediately
```

### CSV Format

#### Base attributes

The following 2 attributes are the bare minimum to create products:
```
productType,variantId
```

You can define the productType via id or name (as long as it is unique).

#### Variants

Variants are defined by leaving the `productType` cell empty and defining a `variantId > 1`:
```
productType,name,variantId,myAttribute
typeName,myProduct,1,value
,,2,other value
,,3,val
otherType,nextProduct,1,foo
,,2,bar
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

> Please note that the `variantId` column must be sorted in ascending order.

Non required product attributes
- slug
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

> Further any custom attribute of type `ltext` can be filled with several language values.

Using the command line option `--language`, you can define in which language the values should be imported.

Multiple languages can be imported by defining for each language an own column with the following schema:
```
productType,name.en,name.de,description.en,description.de,slug.en,slug.de
myType,my Product,mein Produkt,foo bar,bla bal,my-product,mein-product
```

The pattern for the language header is:
`<attribute name>.<language>`

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
productType,variantId,mySameForAllAttribute
myType,1,thisIsTheValueForAllVariants
,2,
,3,thisDifferentValueWillBeIgnored
```

> Please note, that values for those attributes on the variant rows are completely ignored

#### Tax Category

Just provide the name of the tax category in the `tax` column.

#### Categories

In the `categories` column you can define a list of categories the product should be categorized in separated by `;`:
```
Root>Category>SameSubCategory;Root2;Root>Category2>SameSubCategory
```
This example contains 3 categories defined by their full path. The path segments are thereby separated with `>`
to ensure you can link to leaf categories with same names but different bread crumb.

> You can also just use the category name as long as it is unqiue within the whole category tree. In addtion, the category ID (UUID) can also be used.

#### Prices

In the `prices` column you can define a list of prices for each variant separated by `;`:
```
CH-EUR 999 B2B;EUR 899;USD 19900 #retailerA;DE-EUR 1000 B2C#wareHouse1
```
The pattern for one price is:
`<country>-<currenyCode> <centAmount> <customerGroupName>#<channelKey>`

>For the geeks: Have [a look at the regular expression](https://github.com/sphereio/sphere-node-product-csv-sync/blob/e8329dc6a74a560c57a8ab1842decceb42583c0d/src/coffee/constants.coffee#L33) that parses the prices.

mandatory:
- currenyCode
- centAmount

optional:
- country
- customerGroupName
- channel

#### Numbers

Natural numbers are supported. Negative numbers are prepended with a minus (e.g. `-7`).

> Please note that the there is no space allowed between the minus symbol and the digit

#### Images

In the `images` column you can define a list of urls for each variant separated by `;`:
```
https://example.com/image.jpg;http://www.example.com/picture.bmp
```

> In general we recommend to import images without the protocol like `//example.com/image.png`

## Product State

This sub command allows you to publish/unpublish or delele as set of (or all) products with once call.

### Usage

```
node lib/run state --help

  Usage: state --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --changeTo <state>

  Options:

    -h, --help                             output usage information
    --changeTo <publish,unpublish,delete>  publish unpublished products / unpublish published products / delete unpublished products
    --csv <file>                           processes products defined in a CSV file by either "sku" or "id". Otherwise all products are processed.
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
node lib/run template --help

  Usage: template --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --out <file>

  Options:

    -h, --help                   output usage information
    -o, --out <file>             Path to the file the exporter will write the resulting CSV in
    -l, --languages [lang,lang]  List of languages to use for template
    --all                        Generates one template for all product types - if not given you will be ask which product type to use
```


## Export

The export action dumps products to a CSV file. The CSV file may then later be used as input for the import action.

### CSV Export Template

An export template defines the content of the resulting export CSV file, by listing wanted product attribute names as header row. The header column values will be parsed and the resulting export CSV file will contain corresponding attribute values of the exported products.

```
# only productType.name, the variant id and localized name (english) will be exported
productType,name.en,varianId
```

> Please see section [template]() on how to generate a template.

### Usage

```
node lib/run export --help

  Usage: export --projectKey <project-key> --clientId <client-id> --clientSecret <client-secret> --template <file> --out <file>

  Options:

    -h, --help             output usage information
    -t, --template <file>  CSV file containing your header that defines what you want to export
    -o, --out <file>       Path to the file the exporter will write the resulting CSV in
    -j, --json <file>      Path to the JSON file the exporter will write the resulting products
    -l, --language [lang]  Language used on export for category names
    -q, --queryString      Query string to specify the subset of products to export. Please note that the query must be URL encoded!
```

#### Export as JSON

You can export all products as JSON by passing a `--json` flag.

##### Example

```
node lib/run.js export --projectKey <project_key> --clientId <client_id> --clientSecret <client_secret> -j out.json
```

#### Export certain products only

You can define the subset of products to export via the `queryString` parameter. The following parameter keys are of interest:
- limit: Defines the number of products to export. `0` means all and is the default.
- staged: `false` will export published products. `true` will export the staged products, which is the default.
- sort: Allows to sort the result set.
- where: Restrict the products to export using predicates.

Please refer to the [API documentation of SPHERE.IO](http://commercetools.de/dev/http-api.html#query-features) for further information regarding the predicates.

> Please note that you have to provide the queryString URL encoded!

##### Example

Query first 10 products of a specific product type
```
limit=10&where=productType(id%3D%2224da8abf-7be6-4b27-9ce6-69ee4b026513%22)
# decoded: limit=0&where=productType(id="24da8abf-7be6-4b27-9ce6-69ee4b026513")
```

## Group Variants

With this sub command you can group several rows in a CSV together as variants of one product.
It will add a column `variantId` to all rows. Thereby rows are handled as a groups if the they have the same value in the column defined via `headerIndex`.

### Usage

```
node lib/run groupvariants --help

  Usage: groupvariants --in <file> --out <file> --headerIndex <number>

  Options:

    -h, --help              output usage information
    --in <file>             Path to CSV file to analyse.
    --out <file>            Path to the file that will contained the product/variant relations.
    --headerIndex <number>  Index of column (starting at 0) header, that defines the identity of variants to one product
```

> Please note that you don't need any of the global command line options, such as `--projectKey` etc for this sub command.

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
