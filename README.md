sphere-node-product-csv-sync
============================

SPHERE.IO component to import and update products via CSV.

[![Build Status](https://travis-ci.org/sphereio/sphere-node-product-csv-sync.png?branch=master)](https://travis-ci.org/sphereio/sphere-node-product-csv-sync) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-node-product-csv-sync/badge.png)](https://coveralls.io/r/sphereio/sphere-node-product-csv-sync) [![Dependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync) [![devDependency Status](https://david-dm.org/sphereio/sphere-node-product-csv-sync/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-node-product-csv-sync#info=devDependencies)

# Usage

> Ensure you have [NodeJS installed](http://support.sphere.io/knowledgebase/articles/307722-install-nodejs-and-get-a-component-running).

```bash
$ node lib/run.js

Usage: node ./lib/run.js --projectKey key --clientId id --clientSecret secret --csv file --language lang --publish

Options:
  --projectKey    your SPHERE.IO project-key                             [required]
  --clientId      your OAuth client id for the SPHERE.IO API             [required]
  --clientSecret  your OAuth client secret for the SPHERE.IO API         [required]
  --csv           CSV file containing products to import                 [required]
  --language      Default language to using during import                [default: "en"]
  --timeout       Set timeout for requests                               [default: 300000]
  --publish       When given, all changes will be published immediately
```

## CSV Format

### Base attributes

The following 3 attributes are the bare minimum to create products:
```
productType,name,variantId
```

You can define the productType via id or name (as long as it is unique).

### Variants

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
row 2: 1st variant of product in row 1
row 3: 2nd variant of product in row 1
row 4: product with master variant
row 5: 1st variant of product in row 4
```

Non required product attributes
- slug
- metaTitle
- metaDescription
- metaKeywords

> The slug is actually required by SPHERE.IO, but will be generated for the given default language out of the `name` column if not provided.

Non required variant attributes
- sku

### Localized attributes

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

> <attribute name>.<language>

#### Tax Category

Just provided the name of the tax category in the `tax` column.

#### Categories

In the `categories` column you can define a list of categories the product should be categorized in separated by `;`:
```
Root>Category>SameSubCategory;Root2;Root>Category2>SameSubCategory
```
This example contains 3 categories defined by their full path. The path segments are thereby separated with `>`
to ensure you can link to leaf categories with same names but different bread crumb.

> You can also use the category name as long as it is unqiue within the whole category tree.

#### Prices

In the `prices` column you can define a list of prices for each variant separated by `;`:
```
CH-EUR 999 B2B;EUR 899
```
The pattern for one price is:
`<country>-<currenyCode> <centAmount> <customerGroupName>`

The `country` and `customerGroupName` part is optional. 

#### Images

In the `images` column you can define a list of urls for each variant separated by `;`:
```
https://example.com/image.jpg;http://www.example.com/picture.bmp
```

> In general we recommend to import images without the protocol like `//example.com/image.png`
