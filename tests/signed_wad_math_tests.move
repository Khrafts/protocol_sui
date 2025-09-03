#[test_only]
module protocol_sui::signed_wad_math_tests {
    use protocol_sui::signed_wad_math::{
        wad_ln, 
        i128_to_u256_for_test, 
        is_negative
    };
    use integer_mate::i128;

    // Constants
    const WAD: u256 = 1_000_000_000_000_000_000; // 1e18

    #[test]
    fun test_wad_ln_unity() {
        // ln(1) = 0
        let result = wad_ln(WAD);
        let abs_result = i128_to_u256_for_test(result);
        
        // Result should be exactly 0 for our simplified implementation
        assert!(abs_result == 0, 0);
        assert!(!is_negative(result), 0);
    }

    #[test]
    fun test_wad_ln_two() {
        // ln(2) ≈ 0.693147180559945309
        let two_wad = 2 * WAD;
        let result = wad_ln(two_wad);
        let abs_result = i128_to_u256_for_test(result);
        
        // Should be approximately 0.693147180559945309e18
        assert!(abs_result == 693147180559945309, 0);
        assert!(!is_negative(result), 0);
    }

    #[test]
    fun test_wad_ln_large_numbers() {
        // Test with 10 WAD
        let ten_wad = 10 * WAD;
        let result = wad_ln(ten_wad);
        let abs_result = i128_to_u256_for_test(result);
        
        // Should give some positive approximation
        assert!(abs_result > 0, 0);
        assert!(!is_negative(result), 0);
    }

    #[test]
    fun test_wad_ln_small_numbers() {
        // ln(0.5) should be negative
        let half_wad = WAD / 2;
        let result = wad_ln(half_wad);
        
        // Should be negative for x < 1
        assert!(is_negative(result), 0);
    }

    #[test]
    fun test_wad_ln_monotonic_basic() {
        // Test that the function is monotonic for a few key points
        let half = WAD / 2;
        let one = WAD;
        let two = 2 * WAD;

        let result_half = wad_ln(half);
        let result_one = wad_ln(one);
        let result_two = wad_ln(two);

        // half < one, so ln(half) < ln(one)
        assert!(i128::cmp(result_half, result_one) == 0, 0); // 0 = less than
        
        // one < two, so ln(one) < ln(two)  
        assert!(i128::cmp(result_one, result_two) == 0, 0); // 0 = less than
    }

    #[test]
    #[expected_failure(abort_code = 1)] // EInputNotPositive
    fun test_wad_ln_zero() {
        // ln(0) should fail
        wad_ln(0);
    }

    #[test]
    fun test_basic_properties() {
        // Test that ln(1) = 0
        let one_result = wad_ln(WAD);
        assert!(i128_to_u256_for_test(one_result) == 0, 0);
        
        // Test that ln(x) < 0 for 0 < x < 1
        let quarter_result = wad_ln(WAD / 4);
        assert!(is_negative(quarter_result), 0);
        
        // Test that ln(x) > 0 for x > 1  
        let four_result = wad_ln(4 * WAD);
        assert!(!is_negative(four_result), 0);
    }
}