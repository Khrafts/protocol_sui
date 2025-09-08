module protocol_sui::minter_gateway {

    // ============ Structs ============

    /// Dummy MinterGateway object for now
    public struct MinterGateway has key {
        id: UID,
        minter_rate: u32,
        total_active_owed_m: u256
    }

    // ============ Initialization ============

    /// Initialize the MinterGateway (dummy implementation)
    fun init(ctx: &mut TxContext) {
        let gateway = MinterGateway {
            id: object::new(ctx),
            minter_rate: 500, // 5% as dummy value (in basis points)
            total_active_owed_m: 1_000_000_000_000 // Dummy value
        };

        transfer::share_object(gateway);
    }

    // ============ View Functions ============

    /// Get the current minter rate
    public fun minter_rate(gateway: &MinterGateway): u32 {
        gateway.minter_rate
    }

    /// Get the total active owed M
    public fun total_active_owed_m(gateway: &MinterGateway): u256 {
        gateway.total_active_owed_m
    }

    // ============ Dummy Setter Functions (for testing) ============

    public fun set_minter_rate(gateway: &mut MinterGateway, rate: u32) {
        gateway.minter_rate = rate;
    }

    public fun set_total_active_owed_m(
        gateway: &mut MinterGateway, amount: u256
    ) {
        gateway.total_active_owed_m = amount;
    }

    #[test_only]
    public fun initialize(ctx: &mut TxContext) {
        init(ctx);
    }
}
