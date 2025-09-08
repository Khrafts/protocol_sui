module protocol_sui::m_token {

    // ============ Structs ============

    /// Dummy MToken object for now
    public struct MToken has key {
        id: UID,
        total_earning_supply: u256
    }

    // ============ Initialization ============

    /// Initialize the MToken (dummy implementation)
    fun init(ctx: &mut TxContext) {
        let token = MToken {
            id: object::new(ctx),
            total_earning_supply: 500_000_000_000 // Dummy value
        };

        transfer::share_object(token);
    }

    // ============ View Functions ============

    /// Get the total earning supply
    public fun total_earning_supply(token: &MToken): u256 {
        token.total_earning_supply
    }

    // ============ Dummy Setter Functions (for testing) ============

    public fun set_total_earning_supply(token: &mut MToken, amount: u256) {
        token.total_earning_supply = amount;
    }

    #[test_only]
    public fun initialize(ctx: &mut TxContext) {
        init(ctx);
    }
}
