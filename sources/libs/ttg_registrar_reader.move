/// Library to read TTG (Two Token Governance) Registrar module parameters
/// This module provides helper functions to read parameters from an external TTG Registrar
module protocol_sui::ttg_registrar_reader {

    // ============ Constants ============

    /// The name of parameter in TTG that defines the earner rate model contract
    const EARNER_RATE_MODEL: vector<u8> = b"earner_rate_model";

    /// The parameter name in TTG that defines the earners list
    const EARNERS_LIST: vector<u8> = b"earners";

    /// The parameter name in TTG that defines whether to ignore the earners list or not
    const EARNERS_LIST_IGNORED: vector<u8> = b"earners_list_ignored";

    /// The parameter name in TTG that defines the time to wait for mint request to be processed
    const MINT_DELAY: vector<u8> = b"mint_delay";

    /// The parameter name in TTG that defines the mint ratio (in basis points)
    const MINT_RATIO: vector<u8> = b"mint_ratio";

    /// The parameter name in TTG that defines the time while mint request can still be processed
    const MINT_TTL: vector<u8> = b"mint_ttl";

    /// The parameter name in TTG that defines the time to freeze minter
    const MINTER_FREEZE_TIME: vector<u8> = b"minter_freeze_time";

    /// The parameter name in TTG that defines the minter rate model contract
    const MINTER_RATE_MODEL: vector<u8> = b"minter_rate_model";

    /// The parameter name in TTG that defines the minters list
    const MINTERS_LIST: vector<u8> = b"minters";

    /// The parameter name in TTG that defines the penalty rate (in basis points)
    const PENALTY_RATE: vector<u8> = b"penalty_rate";

    /// The parameter name in TTG that defines the required interval to update collateral
    const UPDATE_COLLATERAL_INTERVAL: vector<u8> = b"update_collateral_interval";

    /// The parameter name that defines number of signatures required for successful collateral update
    const UPDATE_COLLATERAL_VALIDATOR_THRESHOLD: vector<u8> = b"update_collateral_threshold";

    /// The parameter name in TTG that defines the validators list
    const VALIDATORS_LIST: vector<u8> = b"validators";

    // ============ Public View Functions ============
    // These functions are meant to be inlined and used by other modules
    // They provide a consistent interface for reading TTG parameters

    /// Returns the EARNER_RATE_MODEL parameter key
    public fun earner_rate_model_key(): vector<u8> {
        EARNER_RATE_MODEL
    }

    /// Returns the EARNERS_LIST parameter key
    public fun earners_list_key(): vector<u8> {
        EARNERS_LIST
    }

    /// Returns the EARNERS_LIST_IGNORED parameter key
    public fun earners_list_ignored_key(): vector<u8> {
        EARNERS_LIST_IGNORED
    }

    /// Returns the MINT_DELAY parameter key
    public fun mint_delay_key(): vector<u8> {
        MINT_DELAY
    }

    /// Returns the MINT_RATIO parameter key
    public fun mint_ratio_key(): vector<u8> {
        MINT_RATIO
    }

    /// Returns the MINT_TTL parameter key
    public fun mint_ttl_key(): vector<u8> {
        MINT_TTL
    }

    /// Returns the MINTER_FREEZE_TIME parameter key
    public fun minter_freeze_time_key(): vector<u8> {
        MINTER_FREEZE_TIME
    }

    /// Returns the MINTER_RATE_MODEL parameter key
    public fun minter_rate_model_key(): vector<u8> {
        MINTER_RATE_MODEL
    }

    /// Returns the MINTERS_LIST parameter key
    public fun minters_list_key(): vector<u8> {
        MINTERS_LIST
    }

    /// Returns the PENALTY_RATE parameter key
    public fun penalty_rate_key(): vector<u8> {
        PENALTY_RATE
    }

    /// Returns the UPDATE_COLLATERAL_INTERVAL parameter key
    public fun update_collateral_interval_key(): vector<u8> {
        UPDATE_COLLATERAL_INTERVAL
    }

    /// Returns the UPDATE_COLLATERAL_VALIDATOR_THRESHOLD parameter key
    public fun update_collateral_validator_threshold_key(): vector<u8> {
        UPDATE_COLLATERAL_VALIDATOR_THRESHOLD
    }

    /// Returns the VALIDATORS_LIST parameter key
    public fun validators_list_key(): vector<u8> {
        VALIDATORS_LIST
    }

    // ============ Test Functions ============

    #[test]
    fun test_parameter_keys() {
        assert!(earner_rate_model_key() == b"earner_rate_model", 0);
        assert!(earners_list_key() == b"earners", 0);
        assert!(earners_list_ignored_key() == b"earners_list_ignored", 0);
        assert!(mint_delay_key() == b"mint_delay", 0);
        assert!(mint_ratio_key() == b"mint_ratio", 0);
        assert!(mint_ttl_key() == b"mint_ttl", 0);
        assert!(minter_freeze_time_key() == b"minter_freeze_time", 0);
        assert!(minter_rate_model_key() == b"minter_rate_model", 0);
        assert!(minters_list_key() == b"minters", 0);
        assert!(penalty_rate_key() == b"penalty_rate", 0);
        assert!(update_collateral_interval_key() == b"update_collateral_interval", 0);
        assert!(
            update_collateral_validator_threshold_key()
                == b"update_collateral_threshold",
            0
        );
        assert!(validators_list_key() == b"validators", 0);
    }
}
