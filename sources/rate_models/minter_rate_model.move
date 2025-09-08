module protocol_sui::minter_rate_model {
    use protocol_sui::uint_math;
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};

    // ============ Constants ============

    /// The maximum allowed rate in basis points (400%)
    const MAX_MINTER_RATE: u256 = 40_000;

    // ============ View Functions ============

    /// Get the current minter rate from TTG Registrar
    /// Simple, stateless function - the Sui way
    public fun rate(registrar: &TTGRegistrar): u256 {
        // Fetch base minter rate from TTG Registrar
        let base_minter_rate = ttg_registrar::get_base_minter_rate(registrar);

        // Apply the rate cap
        uint_math::min256(base_minter_rate, MAX_MINTER_RATE)
    }

    /// Get the maximum minter rate constant
    public fun max_rate(): u256 {
        MAX_MINTER_RATE
    }
}
