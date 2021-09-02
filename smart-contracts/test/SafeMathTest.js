const shouldFail = require('./helpers/shouldFail');
const { MAX_UINT256 } = require('./helpers/constants');

const BigNumber = require('bignumber.js');
const SafeMathMock = artifacts.require('SafeMathMock');

const truffleAssert = require('truffle-assertions');

require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

contract('SafeMath', function () {
  beforeEach(async function () {
    this.safeMath = await SafeMathMock.new();
  });

  describe('add', function () {
    it('adds correctly', async function () {
      const a = new BigNumber(5678);
      const b = new BigNumber(1234);

      ((await this.safeMath.add(a, b)).toString()).should.be.equal(a.plus(b).toString());
    });

    /*it('throws a revert error on addition overflow', async function () {
      const a = MAX_UINT256;
      const b = new BigNumber(1);

      await shouldFail.throwing(this.safeMath.add(a, b));
    });*/
  });

  describe('sub', function () {
    it('subtracts correctly', async function () {
      const a = new BigNumber(5678);
      const b = new BigNumber(1234);

      ((await this.safeMath.sub(a, b)).toString()).should.be.equal(a.minus(b).toString());
    });

    it('throws a revert error if subtraction result would be negative', async function () {
      const a = new BigNumber(1234);
      const b = new BigNumber(5678);

      await shouldFail.throwing(this.safeMath.sub(a, b));
    });
  });

  describe('mul', function () {
    it('multiplies correctly', async function () {
      const a = new BigNumber(1234);
      const b = new BigNumber(5678);

      ((await this.safeMath.mul(a, b)).toString()).should.be.equal(a.times(b).toString());
    });

    it('handles a zero product correctly', async function () {
      const a = new BigNumber(0);
      const b = new BigNumber(5678);

      ((await this.safeMath.mul(a, b)).toString()).should.be.equal(a.times(b).toString());
    });

    /*it('throws a revert error on multiplication overflow', async function () {
      const a = MAX_UINT256;
      const b = new BigNumber(2);

      await shouldFail.throwing(this.safeMath.mul(a, b));
    });*/
  });

  describe('div', function () {
    it('divides correctly', async function () {
      const a = new BigNumber(5678);
      const b = new BigNumber(5678);

      ((await this.safeMath.div(a, b)).toString()).should.be.equal(a.div(b).toString());
    });

    it('throws a revert error on zero division', async function () {
      const a = new BigNumber(5678);
      const b = new BigNumber(0);

      await shouldFail.throwing(this.safeMath.div(a, b));
    });
  });
});
