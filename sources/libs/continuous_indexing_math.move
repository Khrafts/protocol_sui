module protocol_sui::continuous_indexing_math {
    // ============ Constants ============

    /// The number of seconds in a year
    const SECONDS_PER_YEAR: u32 = 31_536_000;

    /// 100% in basis points
    const BPS_SCALED_ONE: u32 = 10_000;

    /// The scaling of rates for exponent math
    const EXP_SCALED_ONE: u64 = 1_000_000_000_000;

    // ============ Error Constants ============

    /// Error when division by zero occurs
    const EDivisionByZero: u64 = 1;

    // ============ Public Functions ============

    /// Helper function to calculate `(x * EXP_SCALED_ONE) / index`, rounded down
    public fun divide_down(x: u256, index: u128): u128 {
        assert!(index != 0, EDivisionByZero);

        let x_scaled = (x as u256) * (EXP_SCALED_ONE as u256);
        let result = x_scaled / (index as u256);
        (result as u128)
    }

    /// Helper function to calculate `(x * EXP_SCALED_ONE) / index`, rounded up
    public fun divide_up(x: u256, index: u128): u128 {
        assert!(index != 0, EDivisionByZero);

        let x_scaled = (x as u256) * (EXP_SCALED_ONE as u256);
        let result = (x_scaled + (index as u256) - 1) / (index as u256);
        (result as u128)
    }

    /// Helper function to calculate `(x * index) / EXP_SCALED_ONE`, rounded down
    public fun multiply_down(x: u128, index: u128): u256 {
        let product = (x as u256) * (index as u256);
        product / (EXP_SCALED_ONE as u256)
    }

    /// Helper function to calculate `(x * index) / EXP_SCALED_ONE`, rounded up
    public fun multiply_up(x: u128, index: u128): u256 {
        let product = (x as u256) * (index as u256);
        (product + (EXP_SCALED_ONE as u256) - 1) / (EXP_SCALED_ONE as u256)
    }

    /// Helper function to calculate `(index * delta_index) / EXP_SCALED_ONE`, rounded down
    public fun multiply_indices_down(index: u128, delta_index: u64): u256 {
        let product = (index as u256) * (delta_index as u256);
        product / (EXP_SCALED_ONE as u256)
    }

    /// Helper function to calculate `(index * delta_index) / EXP_SCALED_ONE`, rounded up
    public fun multiply_indices_up(index: u128, delta_index: u64): u256 {
        let product = (index as u256) * (delta_index as u256);
        (product + (EXP_SCALED_ONE as u256) - 1) / (EXP_SCALED_ONE as u256)
    }

    /// Helper function to calculate e^rt (continuous compounding formula)
    public fun get_continuous_index(yearly_rate: u64, time: u32): u64 {
        let rate_time = (yearly_rate as u256) * (time as u256);
        let x = (rate_time / (SECONDS_PER_YEAR as u256)) as u128;
        exponent(x)
    }

    /// Helper function to calculate y = e^x using R(4,4) Pad� approximation
    /// e(x) = (1 + x/2 + 3(x^2)/28 + x^3/84 + x^4/1680) / (1 - x/2 + 3(x^2)/28 - x^3/84 + x^4/1680)
    public fun exponent(x: u128): u64 {
        let x256 = (x as u256);
        let x2 = x256 * x256;

        // additiveTerms is (1 + 3(x^2)/28 + x^4/1680), scaled by 84e27
        let additive_terms =
            84_000_000_000_000_000_000_000_000_000 + (9_000 * x2)
                + ((x2 / 200_000_000_000) * (x2 / 100_000_000_000));

        // differentTerms is (- x/2 - x^3/84), but positive (will be subtracted later), scaled by 84e27
        let different_terms = x256 * (42_000_000_000_000_000 + (x2 / 1_000_000_000));

        // Result needs to be scaled by 1e12
        let numerator = (additive_terms + different_terms) * 1_000_000_000_000;
        let denominator = additive_terms - different_terms;

        ((numerator / denominator) as u64)
    }

    /// Helper function to convert 12-decimal representation to basis points
    public fun convert_to_basis_points(input: u64): u64 {
        let scaled = (input as u256) * (BPS_SCALED_ONE as u256);
        ((scaled / (EXP_SCALED_ONE as u256)) as u64)
    }

    /// Helper function to convert basis points to 12-decimal representation
    public fun convert_from_basis_points(input: u32): u64 {
        let scaled = (input as u256) * (EXP_SCALED_ONE as u256);
        ((scaled / (BPS_SCALED_ONE as u256)) as u64)
    }

}
