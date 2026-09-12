import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const business = accounts.get("wallet_1")!;
const funder = accounts.get("wallet_2")!;
const stranger = accounts.get("wallet_3")!;

const REGISTRY = "flowfi-registry";
const ESCROW = "flowfi-escrow";
const MOCK_SBTC = "mock-sbtc-token";

const HASH32 = Cl.bufferFromHex("aa".repeat(32));

function getCurrentBurnBlock() {
  return simnet.burnBlockHeight;
}

function mintSbtc(to: string, amount: number) {
  const { result } = simnet.callPublicFn(MOCK_SBTC, "mint", [Cl.uint(amount), Cl.principal(to)], deployer);
  expect(result).toBeOk(Cl.bool(true));
}

// Wires escrow.clar as registry's authorized caller, AND points escrow at
// the mock sBTC token instead of its real-mainnet-address default. Every
// test that expects fund-receivable/release-funds/repay-receivable/
// mark-default to actually succeed needs this.
function wireContracts() {
  const wire1 = simnet.callPublicFn(
    REGISTRY,
    "set-escrow-contract",
    [Cl.contractPrincipal(deployer, ESCROW)],
    deployer
  );
  expect(wire1.result).toBeOk(Cl.bool(true));

  const wire2 = simnet.callPublicFn(
    ESCROW,
    "set-sbtc-contract",
    [Cl.contractPrincipal(deployer, MOCK_SBTC)],
    deployer
  );
  expect(wire2.result).toBeOk(Cl.bool(true));
}

function registerAndVerifyBusiness(owner: string) {
  const reg = simnet.callPublicFn(
    REGISTRY,
    "register-business",
    [Cl.stringAscii("Acme Exports"), Cl.stringAscii("NG")],
    owner
  );
  expect(reg.result).toBeOk(Cl.uint(1));

  const verify = simnet.callPublicFn(
    REGISTRY,
    "verify-business",
    [Cl.uint(1), Cl.uint(1), Cl.uint(1), Cl.uint(0), Cl.principal(deployer), HASH32, HASH32],
    deployer
  );
  expect(verify.result).toBeOk(Cl.bool(true));
}

function registerReceivable(owner: string, dueDate = getCurrentBurnBlock() + 50) {
  const { result } = simnet.callPublicFn(
    REGISTRY,
    "register-receivable",
    [
      Cl.uint(1),
      Cl.stringAscii("Contoso Ltd"),
      Cl.stringAscii("US"),
      Cl.stringAscii("INV-0001"),
      HASH32,
      Cl.uint(2_000_000),
      Cl.uint(1_800_000),
      Cl.uint(0),
      Cl.uint(dueDate),
    ],
    owner
  );
  expect(result).toBeOk(Cl.uint(1));
}

function fundReceivable(as: string) {
  return simnet.callPublicFn(ESCROW, "fund-receivable", [Cl.uint(1), Cl.contractPrincipal(deployer, MOCK_SBTC)], as);
}

function releaseFunds(as = deployer) {
  return simnet.callPublicFn(ESCROW, "release-funds", [Cl.uint(1), Cl.contractPrincipal(deployer, MOCK_SBTC)], as);
}

function repayReceivable(as: string) {
  return simnet.callPublicFn(ESCROW, "repay-receivable", [Cl.uint(1), Cl.contractPrincipal(deployer, MOCK_SBTC)], as);
}

describe("FlowFi - Escrow Contract", () => {
  describe("fund-receivable", () => {
    it("should create an escrow record and move the registry receivable to FUNDED", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);

      const { result } = fundReceivable(funder);
      expect(result).toBeOk(Cl.uint(1)); // escrow-id 1

      const status = simnet.callReadOnlyFn(REGISTRY, "get-receivable-status", [Cl.uint(1)], funder);
      expect(status.result).toBeOk(Cl.uint(2)); // STATUS-FUNDED
    });

    it("should pull exactly the receivable's funding-amount from the funder, not a caller-supplied amount", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);

      const funderBalance = simnet.callReadOnlyFn(MOCK_SBTC, "get-balance", [Cl.principal(funder)], funder);
      // 5,000,000 minted - 1,800,000 funding-amount = 3,200,000 left
      expect(funderBalance.result).toBeOk(Cl.uint(3_200_000));
    });

    it("should reject funding when the receivable isn't OPEN", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      simnet.callPublicFn(REGISTRY, "cancel-receivable", [Cl.uint(1)], business);
      mintSbtc(funder, 5_000_000);

      const { result } = fundReceivable(funder);
      expect(result).toBeErr(Cl.uint(203)); // ERR-RECEIVABLE-NOT-OPEN
    });

    it("should reject a second funding attempt for the same receivable", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      mintSbtc(stranger, 5_000_000);

      // Registry already flipped the receivable to FUNDED on the first call,
      // so the second attempt is caught by the REGISTRY-STATUS-OPEN check
      // before it ever reaches escrow's own is-none(map-get? escrows ...)
      // safety net.
      const { result } = fundReceivable(stranger);
      expect(result).toBeErr(Cl.uint(203)); // ERR-RECEIVABLE-NOT-OPEN
    });

    it("should reject the business funding its own receivable", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(business, 5_000_000);

      const { result } = fundReceivable(business);
      expect(result).toBeErr(Cl.uint(205)); // ERR-SELF-FUNDING
    });

    it("should reject a token contract other than the one configured on escrow", () => {
      // Deliberately wire ONLY registry->escrow, skipping escrow's
      // set-sbtc-contract -- escrow's default still points at the real
      // mainnet sbtc-token address, not the mock. The mock genuinely exists
      // and is trait-conformant (no NoSuchContract risk), it just isn't the
      // one escrow trusts.
      simnet.callPublicFn(REGISTRY, "set-escrow-contract", [Cl.contractPrincipal(deployer, ESCROW)], deployer);
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);

      const { result } = fundReceivable(funder);
      expect(result).toBeErr(Cl.uint(202)); // ERR-WRONG-TOKEN

      // And nothing moved: the funder's balance is untouched.
      const funderBalance = simnet.callReadOnlyFn(MOCK_SBTC, "get-balance", [Cl.principal(funder)], funder);
      expect(funderBalance.result).toBeOk(Cl.uint(5_000_000));
    });

    it("should reject funding a receivable that doesn't exist", () => {
      wireContracts();
      const { result } = simnet.callPublicFn(
        ESCROW,
        "fund-receivable",
        [Cl.uint(999), Cl.contractPrincipal(deployer, MOCK_SBTC)],
        funder
      );
      expect(result).toBeErr(Cl.uint(201)); // ERR-NOT-FOUND
    });
  });

  describe("release-funds", () => {
    it("should pay the business and record released-at", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);

      const { result } = releaseFunds();
      expect(result).toBeOk(Cl.bool(true));

      const businessBalance = simnet.callReadOnlyFn(MOCK_SBTC, "get-balance", [Cl.principal(business)], business);
      expect(businessBalance.result).toBeOk(Cl.uint(1_800_000));
    });

    it("should reject release from a non-admin", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);

      const { result } = releaseFunds(stranger);
      expect(result).toBeErr(Cl.uint(200)); // ERR-NOT-AUTHORIZED
    });

    it("should reject releasing the same escrow twice", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();

      const { result } = releaseFunds();
      expect(result).toBeErr(Cl.uint(207)); // ERR-ALREADY-RELEASED
    });
  });

  describe("repay-receivable", () => {
    it("should pay the funder and move both escrow and registry to REPAID", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();

      const { result } = repayReceivable(business);
      expect(result).toBeOk(Cl.bool(true));

      const status = simnet.callReadOnlyFn(REGISTRY, "get-receivable-status", [Cl.uint(1)], funder);
      expect(status.result).toBeOk(Cl.uint(3)); // STATUS-REPAID

      const funderBalance = simnet.callReadOnlyFn(MOCK_SBTC, "get-balance", [Cl.principal(funder)], funder);
      // 5,000,000 minted - 1,800,000 funded out + 1,800,000 repaid back = 5,000,000
      expect(funderBalance.result).toBeOk(Cl.uint(5_000_000));
    });

    it("should reject repayment before release-funds has been called", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);

      const { result } = repayReceivable(business);
      expect(result).toBeErr(Cl.uint(208)); // ERR-NOT-RELEASED
    });

    it("should reject repayment from someone other than the business", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();

      const { result } = repayReceivable(stranger);
      expect(result).toBeErr(Cl.uint(209)); // ERR-NOT-BUSINESS
    });
  });

  describe("mark-default", () => {
    it("should reject marking default before the due date", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business, getCurrentBurnBlock() + 50);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();

      const { result } = simnet.callPublicFn(ESCROW, "mark-default", [Cl.uint(1)], deployer);
      expect(result).toBeErr(Cl.uint(210)); // ERR-NOT-DUE
    });

    it("should move escrow and registry to DEFAULTED once the due date has passed", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business, getCurrentBurnBlock() + 10);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();

      // Advance BURN block height, not just Stacks block height -- these are
      // decoupled from epoch 3.0 / Nakamoto onward, and the due-date stored
      // in registry.clar is a burn-block height.
      simnet.mineEmptyBurnBlocks(15);

      const { result } = simnet.callPublicFn(ESCROW, "mark-default", [Cl.uint(1)], deployer);
      expect(result).toBeOk(Cl.bool(true));

      const status = simnet.callReadOnlyFn(REGISTRY, "get-receivable-status", [Cl.uint(1)], funder);
      expect(status.result).toBeOk(Cl.uint(4)); // STATUS-DEFAULTED
    });

    it("should reject marking default from a non-admin", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business, getCurrentBurnBlock() + 10);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();
      simnet.mineEmptyBurnBlocks(15);

      const { result } = simnet.callPublicFn(ESCROW, "mark-default", [Cl.uint(1)], stranger);
      expect(result).toBeErr(Cl.uint(200)); // ERR-NOT-AUTHORIZED
    });

    it("should reject defaulting a receivable that has already been repaid", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business, getCurrentBurnBlock() + 10);
      mintSbtc(funder, 5_000_000);
      fundReceivable(funder);
      releaseFunds();
      repayReceivable(business);
      simnet.mineEmptyBurnBlocks(15);

      const { result } = simnet.callPublicFn(ESCROW, "mark-default", [Cl.uint(1)], deployer);
      expect(result).toBeErr(Cl.uint(206)); // ERR-INVALID-STATUS
    });
  });

  describe("admin configuration", () => {
    it("should reject set-sbtc-contract from a non-admin", () => {
      const { result } = simnet.callPublicFn(
        ESCROW,
        "set-sbtc-contract",
        [Cl.contractPrincipal(deployer, MOCK_SBTC)],
        stranger
      );
      expect(result).toBeErr(Cl.uint(200)); // ERR-NOT-AUTHORIZED
    });
  });

  describe("end-to-end", () => {
    it("happy path: register -> verify -> fund -> release -> repay", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business);
      mintSbtc(funder, 5_000_000);

      expect(fundReceivable(funder).result).toBeOk(Cl.uint(1));
      expect(releaseFunds().result).toBeOk(Cl.bool(true));
      expect(repayReceivable(business).result).toBeOk(Cl.bool(true));

      const status = simnet.callReadOnlyFn(REGISTRY, "get-receivable-status", [Cl.uint(1)], funder);
      expect(status.result).toBeOk(Cl.uint(3)); // STATUS-REPAID
    });

    it("default path: register -> verify -> fund -> release -> miss due date -> default", () => {
      wireContracts();
      registerAndVerifyBusiness(business);
      registerReceivable(business, getCurrentBurnBlock() + 10);
      mintSbtc(funder, 5_000_000);

      expect(fundReceivable(funder).result).toBeOk(Cl.uint(1));
      expect(releaseFunds().result).toBeOk(Cl.bool(true));
      simnet.mineEmptyBurnBlocks(15);
      expect(simnet.callPublicFn(ESCROW, "mark-default", [Cl.uint(1)], deployer).result).toBeOk(Cl.bool(true));

      const status = simnet.callReadOnlyFn(REGISTRY, "get-receivable-status", [Cl.uint(1)], funder);
      expect(status.result).toBeOk(Cl.uint(4)); // STATUS-DEFAULTED
    });
  });
});