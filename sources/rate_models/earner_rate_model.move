module protocol_sui::earner_rate_model {
    use protocol_sui::signed_wad_math::wad_ln;
    use protocol_sui::continuous_indexing_math;
    use protocol_sui::uint_math;
    use protocol_sui::minter_gateway::{Self, MinterGateway};
    use protocol_sui::m_token::{Self, MToken};
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};
    use integer_mate::i128;
    
    // ============ Constants ============
    
    /// 30 days in seconds - confidence interval for rate calculations
    const RATE_CONFIDENCE_INTERVAL: u32 = 2_592_000; // 30 * 24 * 60 * 60
    
    /// 98% in basis points - rate multiplier for extra safety margin
    const RATE_MULTIPLIER: u32 = 9_800;
    
    /// 100% in basis points
    const ONE: u32 = 10_000;
    
    /// The scaling of rates for exponent math (1e12)
    const EXP_SCALED_ONE: u256 = 1_000_000_000_000;
    
    /// The scaling of EXP_SCALED_ONE for wad math operations (1e6)
    const WAD_TO_EXP_SCALER: u256 = 1_000_000;
    
    /// The number of seconds in a year (for compatibility)
    const SECONDS_PER_YEAR: u32 = 31_536_000;
    
    // ============ View Functions ============
    
    /// Get the current earner rate by calling protocol modules directly
    /// This matches the Solidity implementation's external calls
    public fun rate_with_refs(
        minter_gateway: &MinterGateway,
        m_token: &MToken,
        ttg_registrar: &TTGRegistrar
    ): u256 {
        // Fetch values from protocol modules - exactly like Solidity does
        let max_earner_rate = ttg_registrar::get_max_earner_rate(ttg_registrar);
        let minter_rate = minter_gateway::minter_rate(minter_gateway);
        let total_active_owed_m = minter_gateway::total_active_owed_m(minter_gateway);
        let total_earning_supply = m_token::total_earning_supply(m_token);
        
        // Call the pure calculation function
        rate(max_earner_rate, minter_rate, total_active_owed_m, total_earning_supply)
    }
    
    /// Pure function version of rate calculation
    /// This can be called without the EarnerRateModel object for testing/flexibility
    public fun rate(
        max_earner_rate: u256,
        minter_rate: u32,
        total_active_owed_m: u256,
        total_earning_supply: u256
    ): u256 {
        // If there are no active minters or minter rate is zero, do not accrue yield to earners
        if (total_active_owed_m == 0 || minter_rate == 0) {
            return 0
        };
        
        // NOTE: If `earnerRate` <= `minterRate` and there are no deactivated minters in the system,
        //       it is safe to return `earnerRate` as the effective rate
        if (max_earner_rate <= (minter_rate as u256) && total_active_owed_m >= total_earning_supply) {
            return max_earner_rate
        };
        
        let extra_safe_rate = get_extra_safe_earner_rate(
            total_active_owed_m,
            total_earning_supply,
            minter_rate
        );
        
        uint_math::min256(max_earner_rate, (extra_safe_rate as u256))
    }
    
    /// Get the maximum earner rate from configuration
    /// In production, this would query the TTG Registrar
    /// @param ttg_registrar_value: The value stored in TTG Registrar for max_earner_rate
    /// @return The maximum earner rate
    public fun max_rate(ttg_registrar_value: u256): u256 {
        ttg_registrar_value
    }
    
    /// Calculate the extra safe earner rate with safety margin
    /// @param total_active_owed_m: Total active owed M tokens
    /// @param total_earning_supply: Total earning supply
    /// @param minter_rate: Current minter rate in basis points
    /// @return Extra safe earner rate in basis points
    public fun get_extra_safe_earner_rate(
        total_active_owed_m: u256,
        total_earning_supply: u256,
        minter_rate: u32
    ): u32 {
        let safe_earner_rate = get_safe_earner_rate(
            total_active_owed_m,
            total_earning_supply,
            minter_rate
        );
        
        let extra_safe_earner_rate = ((safe_earner_rate as u256) * (RATE_MULTIPLIER as u256)) / (ONE as u256);
        
        if (extra_safe_earner_rate > 0xFFFFFFFF) {
            0xFFFFFFFF // type(uint32).max
        } else {
            (extra_safe_earner_rate as u32)
        }
    }
    
    /// Calculate the safe earner rate
    /// Implements complex math to ensure cashflow safety
    /// @param total_active_owed_m: Total active owed M tokens
    /// @param total_earning_supply: Total earning supply
    /// @param minter_rate: Current minter rate in basis points
    /// @return Safe earner rate in basis points
    public fun get_safe_earner_rate(
        total_active_owed_m: u256,
        total_earning_supply: u256,
        minter_rate: u32
    ): u32 {
        if (total_active_owed_m == 0 || minter_rate == 0) {
            return 0
        };
        
        if (total_earning_supply == 0) {
            return 0xFFFFFFFF // type(uint32).max
        };
        
        // When totalActiveOwedM <= totalEarningSupply, use instantaneous rate
        if (total_active_owed_m <= total_earning_supply) {
            // NOTE: Can overflow in distant future, but matches Solidity behavior
            let rate = (total_active_owed_m * (minter_rate as u256)) / total_earning_supply;
            if (rate > 0xFFFFFFFF) {
                0xFFFFFFFF
            } else {
                (rate as u32)
            }
        } else {
            // Complex calculation for when totalActiveOwedM > totalEarningSupply
            // Uses natural logarithm to ensure safety over RATE_CONFIDENCE_INTERVAL
            
            let minter_rate_scaled = continuous_indexing_math::convert_from_basis_points(minter_rate);
            let delta_minter_index = continuous_indexing_math::get_continuous_index(
                minter_rate_scaled,
                RATE_CONFIDENCE_INTERVAL
            ) as u256;
            
            // Calculate: 1 + (totalActive * (deltaMinterIndex - 1) / totalEarning)
            let delta_part = delta_minter_index - EXP_SCALED_ONE;
            let scaled_part = (total_active_owed_m * delta_part) / total_earning_supply;
            let ln_arg = EXP_SCALED_ONE + scaled_part;
            
            // Convert to proper format for wadLn calculation
            // wadLn expects u256 input scaled by WAD (1e18)
            // Our ln_arg is scaled by EXP_SCALED_ONE (1e12), need to scale up by 1e6
            let ln_arg_wad = ln_arg * WAD_TO_EXP_SCALER;
            let ln_result_i128 = wad_ln(ln_arg_wad);
            
            // Convert I128 result back to u256
            // ln_result should be positive for valid inputs
            assert!(i128::sign(ln_result_i128) == 0, 2); // 0 means positive in i128
            let ln_result_u128 = i128::as_u128(ln_result_i128);
            let ln_result_wad = (ln_result_u128 as u256);
            
            // Scale down from WAD (1e18) to EXP (1e12) for our calculations
            let ln_result_u256 = ln_result_wad / WAD_TO_EXP_SCALER;
            
            // Calculate the rate: ln_result * SECONDS_PER_YEAR / RATE_CONFIDENCE_INTERVAL
            let exp_rate = (ln_result_u256 * (SECONDS_PER_YEAR as u256)) / (RATE_CONFIDENCE_INTERVAL as u256);
            
            if (exp_rate > 0xFFFFFFFFFFFFFFFF) { // type(uint64).max
                return 0xFFFFFFFF // type(uint32).max
            };
            
            let safe_rate = continuous_indexing_math::convert_to_basis_points((exp_rate as u64)) as u32;
            
            safe_rate
        }
    }
}