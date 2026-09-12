import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const business = accounts.get("wallet_1")!;
const otherBusiness = accounts.get("wallet_2")!;
const stranger = accounts.get("wallet_3")!;

const REGISTRY = "flowfi-registry";
const HASH32 = Cl.bufferFromHex("aa".repeat(32)); // dummy 32-byte hash for verification fields

function getCurrentBurnBlock() {
  return simnet.burnBlockHeight;
}

function registerBusiness(owner: string, name = "Acme Exports", country = "NG") {
  return simnet.callPublicFn(REGISTRY, "register-business", [Cl.stringAscii(name), Cl.stringAscii(country)], owner);
}

function verifyBusiness(businessId: number, opts: { expiry?: number; verifier?: string } = {}) {
  const verifier = opts.verifier ?? deployer; // deployer is the default verifier
  return simnet.callPublicFn(
    REGISTRY,
    "verify-business",
    [
      Cl.uint(businessId),
      Cl.uint(1), // METHOD-CAC
      Cl.uint(1), // LEVEL-BASIC
      Cl.uint(opts.expiry ?? 0), // 0 = no expiry
      Cl.principal(verifier),
      HASH32,
      HASH32,
    ],
    verifier
  );
}

function registerReceivable(
  owner: string,
  businessId: number,
  overrides: Partial<{ dueDate: number; issueDate: number; faceValue: number; fundingAmount: number }> = {}
) {
  return simnet.callPublicFn(
    REGISTRY,
    "register-receivable",
    [
      Cl.uint(businessId),
      Cl.stringAscii("Contoso Ltd"),
      Cl.stringAscii("US"),
      Cl.stringAscii("INV-0001"),
      HASH32,
      Cl.uint(overrides.faceValue ?? 2_000_000),
      Cl.uint(overrides.fundingAmount ?? 1_800_000),
      Cl.uint(overrides.issueDate ?? 0),
      Cl.uint(overrides.dueDate ?? getCurrentBurnBlock() + 50),
    ],
    owner
  );
}

describe("FlowFi - Registry Contract", () => {
  describe("register-business", () => {
    it("should register a new business and assign an incrementing id", () => {
      const r1 = registerBusiness(business);
      expect(r1.result).toBeOk(Cl.uint(1));
      const r2 = registerBusiness(otherBusiness, "Beta Co", "US");
      expect(r2.result).toBeOk(Cl.uint(2));
    });

    it("should reject a second registration from the same wallet", () => {
      registerBusiness(business);
      const { result } = registerBusiness(business, "Acme 2");
      expect(result).toBeErr(Cl.uint(102)); // ERR-ALREADY-REGISTERED
    });

    it("should reject an empty business name", () => {
      const { result } = registerBusiness(business, "");
      expect(result).toBeErr(Cl.uint(103)); // ERR-INVALID-NAME
    });

    it("should reject a country code shorter than 2 characters", () => {
      // string-ascii 2 already bounds the max length at the ABI level, so
      // only "too short" (0 or 1 chars) can reach our own length check.
      const { result } = registerBusiness(business, "Acme", "N");
      expect(result).toBeErr(Cl.uint(104)); // ERR-INVALID-COUNTRY
    });
  });

  describe("verify-business", () => {
    it("should let the verifier verify a registered business", () => {
      registerBusiness(business);
      const { result } = verifyBusiness(1);
      expect(result).toBeOk(Cl.bool(true));
    });

    it("should reject verification from a non-verifier", () => {
      registerBusiness(business);
      const { result } = verifyBusiness(1, { verifier: stranger });
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });

    it("should reject an out-of-range verification-method", () => {
      registerBusiness(business);
      const { result } = simnet.callPublicFn(
        REGISTRY,
        "verify-business",
        [Cl.uint(1), Cl.uint(6), Cl.uint(1), Cl.uint(0), Cl.principal(deployer), HASH32, HASH32],
        deployer
      );
      expect(result).toBeErr(Cl.uint(111)); // ERR-INVALID-VERIFICATION-METHOD
    });

    it("should reject an out-of-range verification-level", () => {
      registerBusiness(business);
      const { result } = simnet.callPublicFn(
        REGISTRY,
        "verify-business",
        [Cl.uint(1), Cl.uint(1), Cl.uint(4), Cl.uint(0), Cl.principal(deployer), HASH32, HASH32],
        deployer
      );
      expect(result).toBeErr(Cl.uint(112)); // ERR-INVALID-VERIFICATION-LEVEL
    });

    it("should reject a verification-expiry that is not in the future", () => {
      registerBusiness(business);
      // Passing exactly the current height: the contract requires strictly
      // greater, so "right now" must not count as "still valid".
      const { result } = verifyBusiness(1, { expiry: getCurrentBurnBlock() });
      expect(result).toBeErr(Cl.uint(109)); // ERR-INVALID-DATE
    });
  });

  describe("revoke-verification", () => {
    it("should let the verifier revoke a verified business", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = simnet.callPublicFn(REGISTRY, "revoke-verification", [Cl.uint(1)], deployer);
      expect(result).toBeOk(Cl.bool(true));

      const verified = simnet.callReadOnlyFn(REGISTRY, "is-business-verified", [Cl.uint(1)], deployer);
      expect(verified.result).toBeBool(false);
    });

    it("should reject revocation from a non-verifier", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = simnet.callPublicFn(REGISTRY, "revoke-verification", [Cl.uint(1)], stranger);
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe("is-business-verified", () => {
    it("should return false for a business that was never verified", () => {
      registerBusiness(business);
      const { result } = simnet.callReadOnlyFn(REGISTRY, "is-business-verified", [Cl.uint(1)], deployer);
      expect(result).toBeBool(false);
    });

    // Demonstrates the lazy-expiry design documented in registry.clar: once
    // verification-expiry has passed, is-business-verified must return false
    // even though the stored verification-status field still literally says
    // VERIFIED -- nothing "notices" the expiry except this re-derivation on
    // every read.
    it("should return false once verification-expiry has passed, even though verification-status still says VERIFIED", () => {
      registerBusiness(business);
      verifyBusiness(1, { expiry: getCurrentBurnBlock() + 10 });
      simnet.mineEmptyBurnBlocks(15); // past expiry

      const { result } = simnet.callReadOnlyFn(REGISTRY, "is-business-verified", [Cl.uint(1)], deployer);
      expect(result).toBeBool(false);
    });
  });

  describe("register-receivable", () => {
    it("should let a verified business owner register a receivable", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = registerReceivable(business, 1);
      expect(result).toBeOk(Cl.uint(1));
    });

    it("should reject registration from an unverified business", () => {
      registerBusiness(business);
      const { result } = registerReceivable(business, 1);
      expect(result).toBeErr(Cl.uint(106)); // ERR-NOT-VERIFIED
    });

    it("should reject registration from a wallet that isn't the business owner", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = registerReceivable(stranger, 1);
      expect(result).toBeErr(Cl.uint(105)); // ERR-NOT-BUSINESS-OWNER
    });

    it("should reject funding-amount exceeding face-value", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = registerReceivable(business, 1, { faceValue: 1000, fundingAmount: 1500 });
      expect(result).toBeErr(Cl.uint(108)); // ERR-FUNDING-EXCEEDS-FACE-VALUE
    });

    it("should reject a due date that is not in the future", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = registerReceivable(business, 1, { dueDate: getCurrentBurnBlock() });
      expect(result).toBeErr(Cl.uint(109)); // ERR-INVALID-DATE
    });

    it("should reject an issue date in the future", () => {
      registerBusiness(business);
      verifyBusiness(1);
      const { result } = registerReceivable(business, 1, { issueDate: getCurrentBurnBlock() + 100 });
      expect(result).toBeErr(Cl.uint(109)); // ERR-INVALID-DATE
    });
  });

  describe("cancel-receivable", () => {
    it("should let the business owner cancel an OPEN receivable", () => {
      registerBusiness(business);
      verifyBusiness(1);
      registerReceivable(business, 1);
      const { result } = simnet.callPublicFn(REGISTRY, "cancel-receivable", [Cl.uint(1)], business);
      expect(result).toBeOk(Cl.bool(true));
    });

    it("should reject cancellation from a non-owner", () => {
      registerBusiness(business);
      verifyBusiness(1);
      registerReceivable(business, 1);
      const { result } = simnet.callPublicFn(REGISTRY, "cancel-receivable", [Cl.uint(1)], stranger);
      expect(result).toBeErr(Cl.uint(105)); // ERR-NOT-BUSINESS-OWNER
    });

    it("should reject cancelling a receivable that is no longer OPEN", () => {
      registerBusiness(business);
      verifyBusiness(1);
      registerReceivable(business, 1);
      simnet.callPublicFn(REGISTRY, "cancel-receivable", [Cl.uint(1)], business);

      const { result } = simnet.callPublicFn(REGISTRY, "cancel-receivable", [Cl.uint(1)], business);
      expect(result).toBeErr(Cl.uint(110)); // ERR-INVALID-STATUS
    });
  });

  // registry.clar's escrow-authorization gate is the single highest-risk
  // piece of this contract: mark-funded/mark-repaid/mark-defaulted must be
  // unreachable by anyone except the configured escrow CONTRACT. These
  // tests exist specifically to prove it fails closed.
  describe("escrow authorization gate", () => {
    it("should reject mark-funded from anyone, including the deployer, before set-escrow-contract is called", () => {
      registerBusiness(business);
      verifyBusiness(1);
      registerReceivable(business, 1);

      const { result } = simnet.callPublicFn(
        REGISTRY,
        "mark-funded",
        [Cl.uint(1), Cl.principal(stranger), Cl.uint(100), Cl.uint(1)],
        deployer
      );
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });

    it("should reject mark-funded called directly by a wallet even after escrow is wired", () => {
      registerBusiness(business);
      verifyBusiness(1);
      registerReceivable(business, 1);
      simnet.callPublicFn(REGISTRY, "set-escrow-contract", [Cl.contractPrincipal(deployer, "escrow")], deployer);

      // contract-caller here is `deployer` the WALLET, not the escrow
      // CONTRACT -- must still fail even though escrow is now configured.
      const { result } = simnet.callPublicFn(
        REGISTRY,
        "mark-funded",
        [Cl.uint(1), Cl.principal(stranger), Cl.uint(100), Cl.uint(1)],
        deployer
      );
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });

  describe("admin configuration", () => {
    it("should let admin reassign the verifier, and only the new verifier can then verify businesses", () => {
      simnet.callPublicFn(REGISTRY, "set-verifier", [Cl.principal(stranger)], deployer);
      registerBusiness(business);

      const asOldVerifier = verifyBusiness(1); // deployer, no longer verifier
      expect(asOldVerifier.result).toBeErr(Cl.uint(100));

      const asNewVerifier = verifyBusiness(1, { verifier: stranger });
      expect(asNewVerifier.result).toBeOk(Cl.bool(true));
    });

    it("should reject admin functions from a non-admin", () => {
      const { result } = simnet.callPublicFn(REGISTRY, "set-verifier", [Cl.principal(stranger)], stranger);
      expect(result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });
  });
});