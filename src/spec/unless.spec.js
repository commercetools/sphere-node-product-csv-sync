/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
describe('understanding unless', function() {
  
  it('with an object', () => expect(!{} ? true : undefined).toBeUndefined());

  it('with null', () => expect(!null ? true : undefined).toBe(true));

  it('with undefined', () => expect(!undefined ? true : undefined).toBe(true));

  it('with empty single quoted string', () => expect(!'' ? true : undefined).toBe(true));

  it('with empty double quoted string', () => expect(!"" ? true : undefined).toBe(true));

  it('with some string', () => expect(!"foo" ? true : undefined).toBeUndefined());

  it('with 0', () => expect(!0 ? true : undefined).toBe(true));

  it('with 1', () => expect(!1 ? true : undefined).toBeUndefined());

  it('with false', () => expect(!false ? true : undefined).toBe(true));

  return it('with true', () => expect(!true ? true : undefined).toBeUndefined());
});
