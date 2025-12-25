import assert from "assert/strict";

import { parseUrlDetails } from './auth.js';

suite("parseUrlDetails", () => {

  test('ssh - github ', () =>  {
    assert.deepStrictEqual({
	host: "github.com",
	owner: "keanemind",
	repo: "jj-stack",
      }, parseUrlDetails('ssh://git@github.com/keanemind/jj-stack.git'));
  });

  test('git - github enterprise', () =>  {
    assert.deepStrictEqual({
	host: "myorg.ghe.com",
	owner: "MyOrg",
	repo: "repo",
      }, parseUrlDetails('myorg@myorg.ghe.com:MyOrg/repo.git'));
  });
});
