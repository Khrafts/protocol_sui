module protocol_sui::continuous_indexing {
    use protocol_sui::continuous_indexing_math;

    // ============ Constants ============

    /// Initial index value (1e12 scaled)
    const EXP_SCALED_ONE: u128 = 1_000_000_000_000;

    // ============ Events ============

    /// Emitted when the index is updated
    public struct IndexUpdatedEvent has copy, drop {
        current_index: u128,
        rate: u32
    }

    // ============ Structs ============

    /// ContinuousIndexing state that tracks index and rate updates
    public struct ContinuousIndexing has store {
        /// The latest index value (uint128 in Solidity → u128)
        latest_index: u128,

        /// The latest rate (uint32 in Solidity → u32)
        latest_rate: u32,

        /// The timestamp of the latest update (uint40 in Solidity → u64)
        latest_update_timestamp: u64
    }

    // ============ Constructor Functions ============

    /// Create a new ContinuousIndexing instance
    public fun new(ctx: &TxContext): ContinuousIndexing {
        ContinuousIndexing {
            latest_index: EXP_SCALED_ONE,
            latest_rate: 0,
            latest_update_timestamp: ctx.epoch_timestamp_ms() / 1000 // Convert ms to seconds
        }
    }

    // ============ View Functions ============

    /// Get the latest index
    public fun latest_index(indexing: &ContinuousIndexing): u128 {
        indexing.latest_index
    }

    /// Get the latest rate
    public fun latest_rate(indexing: &ContinuousIndexing): u32 {
        indexing.latest_rate
    }

    /// Get the latest update timestamp
    public fun latest_update_timestamp(indexing: &ContinuousIndexing): u64 {
        indexing.latest_update_timestamp
    }

    // ============ Update Functions ============

    /// Update the index with a new rate
    public fun update_index(
        indexing: &mut ContinuousIndexing, new_rate: u32, current_timestamp: u64
    ): u128 {
        // If timestamp hasn't changed and rate is the same, return current index
        if (indexing.latest_update_timestamp == current_timestamp
            && indexing.latest_rate == new_rate) {
            return indexing.latest_index
        };

        // Calculate the current index based on time elapsed
        let current_index =
            calculate_current_index(
                indexing.latest_index,
                indexing.latest_rate,
                indexing.latest_update_timestamp,
                current_timestamp
            );

        // Update state
        indexing.latest_index = current_index;
        indexing.latest_rate = new_rate;
        indexing.latest_update_timestamp = current_timestamp;

        current_index
    }

    /// Calculate the current index based on time elapsed
    public fun calculate_current_index(
        latest_index: u128,
        latest_rate: u32,
        latest_update_timestamp: u64,
        current_timestamp: u64
    ): u128 {
        let time_elapsed = current_timestamp - latest_update_timestamp;

        if (time_elapsed == 0) {
            return latest_index
        };

        // Convert rate from basis points and calculate continuous index
        let rate_scaled =
            continuous_indexing_math::convert_from_basis_points(latest_rate);
        let delta_index =
            continuous_indexing_math::get_continuous_index(
                rate_scaled, (time_elapsed as u32)
            );

        // Multiply indices and cap at u128 max
        let result =
            continuous_indexing_math::multiply_indices_down(latest_index, delta_index);

        // Cap at u128 max to prevent overflow (2^128 - 1)
        let u128_max: u256 = 340282366920938463463374607431768211455;
        if (result > u128_max) {
            340282366920938463463374607431768211455u128
        } else {
            (result as u128)
        }
    }

    // ============ Principal/Present Amount Conversion Functions ============

    /// Get principal amount rounded down from present amount
    public fun get_principal_amount_rounded_down(
        present_amount: u256, // uint240 in Solidity → u256
        index: u128
    ): u128 { // uint112 in Solidity → u128
        continuous_indexing_math::divide_down(present_amount, index)
    }

    /// Get principal amount rounded up from present amount
    public fun get_principal_amount_rounded_up(
        present_amount: u256, // uint240 in Solidity → u256
        index: u128
    ): u128 { // uint112 in Solidity → u128
        continuous_indexing_math::divide_up(present_amount, index)
    }

    /// Get present amount rounded down from principal amount
    public fun get_present_amount_rounded_down(
        principal_amount: u128, // uint112 in Solidity → u128
        index: u128
    ): u256 { // uint240 in Solidity → u256
        continuous_indexing_math::multiply_down(principal_amount, index)
    }
}
