/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const QueryUtils = require("../lib/queryutils");
const GLOBALS = require('../lib/globals');

const products = [
  {
    product: {
      masterVariant: {
        id: 1,
        attributes: [
          {
            name: "key",
            value: '1"bar"'
          }
        ],
        sku: '1"foo"'
      },
      variants: [
        {
          attributes: [
            {
              name: "key",
              value: "2"
            }
          ],
          sku: "2"
        },
        {
          id: 3,
          attributes: [
            {
              name: "key",
              value: "3"
            }
          ],
          sku: "3"
        }
      ],
      id: "1",
      slug: {
        en: "1"
      }
    }
  },
  {
    product: {
      masterVariant: {
        id: 1,
        attributes: [
          {
            name: "key",
            value: "4"
          }
        ],
        sku: "4"
      },
      variants: [
        {
          attributes: [
            {
              name: "key",
              value: "5"
            }
          ],
          sku: "5"
        },
        {
          attributes: [
            {
              name: "key",
              value: "6"
            }
          ],
          sku: "6"
        }
      ],
      id: "2",
      slug: {
        en: "2"
      }
    }
  }
];

describe("QueryUtils", function() {

  describe("mapMatchFunction", function() {

    it("should return \"matchById\" function if supplied with \"id\" value", function() {
      const matchFunction = QueryUtils.mapMatchFunction("id");
      expect(matchFunction).toBeDefined();
      return expect(matchFunction).toBe(QueryUtils.matchById);
    });

    it("should return \"matchBySlug\" function if supplied with \"slug\" value", function() {
      const matchFunction = QueryUtils.mapMatchFunction("slug");
      expect(matchFunction).toBeDefined();
      return expect(matchFunction).toBe(QueryUtils.matchBySlug);
    });

    it("should return \"matchBySku\" function if supplied with \"sku\" value", function() {
      const matchFunction = QueryUtils.mapMatchFunction("sku");
      expect(matchFunction).toBeDefined();
      return expect(matchFunction).toBe(QueryUtils.matchBySku);
    });

    return it("should return \"matchByCustomAttribute\" function if supplied with random value", function() {
      const matchFunction = QueryUtils.mapMatchFunction("custom_attribute_name");
      expect(matchFunction).toBeDefined();
      return expect(typeof matchFunction).toEqual('function');
    });
  });

  describe("matchById", () =>
    it("should return query predicte based on products provided", function() {
      const predicate = QueryUtils.matchById(products);
      return expect(predicate).toEqual("id in (\"1\", \"2\")");
    })
  );

  describe("matchBySlug", () =>
    it("should return query predicte based on products provided", function() {
      GLOBALS.DEFAULT_LANGUAGE = "en";
      const predicate = QueryUtils.matchBySlug(products);
      return expect(predicate).toEqual("slug(en in (\"1\", \"2\"))");
    })
  );

  describe("matchBySku", () =>
    it("should return query predicte based on products provided", function() {
      const predicate = QueryUtils.matchBySku(products);
      return expect(predicate).toEqual("masterVariant(sku in " +
      '("1\\"foo\\"", "4")) or ' +
      'variants(sku in ("1\\"foo\\"", "4"))');
    })
  );

  return describe("matchByCustomAttribute", () =>
    it("should return query predicte based on products provided", function() {
      const predicate = QueryUtils.matchByCustomAttribute("key")(products);
      return expect(predicate).toEqual(
        `masterVariant(attributes(name="key" and value in \
("1\\"bar\\"", "2", "3", "4", "5", "6"))) or \
variants(attributes(name="key" and value in \
("1\\"bar\\"", "2", "3", "4", "5", "6")))`
      );
    })
  );
});
