sphere-node-product-csv-sync
============================

SPHERE.IO component to import, update and export products via CSV.

[![Build Status](https://travis-ci.org/sphereio/sphere-node-product-csv-sync.png?branch=master)](https://travis-ci.org/sphereio/sphere-node-product-csv-sync) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-node-product-csv-sync/badge.png)](https://coveralls.io/r/sphereio/sphere-node-product-csv-sync) [![Dependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync) [![devDependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync#info=devDependencies)

# Setup

* install [NodeJS](http://support.sphere.io/knowledgebase/articles/307722-install-nodejs-and-get-a-component-running) (platform for running application) 

### From scratch

* install [npm]((http://gruntjs.com/getting-started)) (NodeJS package manager, bundled with node since version 0.6.3!)
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

## Import

### Usage

```bash
$ node lib/run

Usage: node lib/run --projectKey key --clientId id --clientSecret secret --csv file --language lang --publish

Options:
  --projectKey    your SPHERE.IO project-key                             [required]
  --clientId      your OAuth client id for the SPHERE.IO API             [required]
  --clientSecret  your OAuth client secret for the SPHERE.IO API         [required]
  --csv           CSV file containing products to import                 [required]
  --language      Default language to using during import                [default: "en"]
  --timeout       Set timeout for requests                               [default: 300000]
  --publish       When given, all changes will be published immediately
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

#### Images

In the `images` column you can define a list of urls for each variant separated by `;`:
```
https://example.com/image.jpg;http://www.example.com/picture.bmp
```

> In general we recommend to import images without the protocol like `//example.com/image.png`

## Export

The export action dumps products to a CSV file. The CSV file can be used as input for the import action.

### CSV Export Template

An export template defines the content of the resulting export CSV file, by listing wanted product attribute names as header row. The header column values will be parsed and the resulting export CSV file will contain corresponding attribute values of the eported products.

```
# only productType.name, the variant id and localized name (english) will be exported
productType,name.en,varianId
```

### Usage

```bash
$ node lib/runexporter

Usage: node .lib/runexporter --projectKey key --clientId id --clientSecret secret --template file --out file

Options:
  --projectKey    your SPHERE.IO project-key                                            [required]
  --clientId      your OAuth client id for the SPHERE.IO API                            [required]
  --clientSecret  your OAuth client secret for the SPHERE.IO API                        [required]
  --template      CSV file containing your header that defines what you want to export  [required]
  --out           Path to the file the exporter will write the resulting CSV in         [required]
  --timeout       Set timeout for requests                                              [default: 300000]
  --language                                                                            [default: "en"]
```
