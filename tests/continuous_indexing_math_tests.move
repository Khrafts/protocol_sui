#[test_only]
module protocol_sui::continuous_indexing_math_tests {
    use protocol_sui::continuous_indexing_math::{
        divide_down, 
        divide_up, 
        multiply_down, 
        multiply_up, 
        get_continuous_index, 
        exponent, 
        convert_to_basis_points, 
        convert_from_basis_points
    };

    // Constants imported from the main module
    const EXP_SCALED_ONE: u64 = 1_000_000_000_000;

    #[test]
    fun test_divide_down() {
        // Set 1a
        assert!(divide_down(0, 1) == 0, 0);
        assert!(divide_down(1, 1) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_down(2, 1) == (2 * EXP_SCALED_ONE as u128), 0);
        assert!(divide_down(3, 1) == (3 * EXP_SCALED_ONE as u128), 0);

        // Set 1b
        assert!(divide_down(1, 1) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_down(1, 2) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_down(1, 3) == ((EXP_SCALED_ONE / 3) as u128), 0);

        // Set 2a
        assert!(divide_down(0, 10) == 0, 0);
        assert!(divide_down(5, 10) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_down(10, 10) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_down(15, 10) == ((EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_down(20, 10) == ((2 * EXP_SCALED_ONE) as u128), 0);
        assert!(divide_down(25, 10) == ((2 * EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 0);

        // Set 2b
        assert!(divide_down(10, 5) == ((2 * EXP_SCALED_ONE) as u128), 0);
        assert!(divide_down(10, 10) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_down(10, 15) == (((2 * EXP_SCALED_ONE) / 3) as u128), 0);
        assert!(divide_down(10, 20) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_down(10, 25) == (((2 * EXP_SCALED_ONE) / 5) as u128), 0);

        // Set 3
        assert!(divide_down(1, (EXP_SCALED_ONE as u128) + 1) == 0, 0);
        assert!(divide_down(1, (EXP_SCALED_ONE as u128)) == 1, 0);
        assert!(divide_down(1, (EXP_SCALED_ONE as u128) - 1) == 1, 0);
        assert!(divide_down(1, ((EXP_SCALED_ONE / 2) as u128) + 1) == 1, 0);
        assert!(divide_down(1, ((EXP_SCALED_ONE / 2) as u128)) == 2, 0);
        assert!(divide_down(1, ((EXP_SCALED_ONE / 2) as u128) - 1) == 2, 0);
    }

    #[test]
    fun test_divide_up() {
        // Set 1a
        assert!(divide_up(0, 1) == 0, 0);
        assert!(divide_up(1, 1) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_up(2, 1) == ((2 * EXP_SCALED_ONE) as u128), 0);
        assert!(divide_up(3, 1) == ((3 * EXP_SCALED_ONE) as u128), 0);

        // Set 1b
        assert!(divide_up(1, 1) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_up(1, 2) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_up(1, 3) == ((EXP_SCALED_ONE / 3 + 1) as u128), 0);

        // Set 2a
        assert!(divide_up(0, 10) == 0, 0);
        assert!(divide_up(5, 10) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_up(10, 10) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_up(15, 10) == ((EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_up(20, 10) == ((2 * EXP_SCALED_ONE) as u128), 0);
        assert!(divide_up(25, 10) == ((2 * EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 0);

        // Set 2b
        assert!(divide_up(10, 5) == ((2 * EXP_SCALED_ONE) as u128), 0);
        assert!(divide_up(10, 10) == (EXP_SCALED_ONE as u128), 0);
        assert!(divide_up(10, 15) == (((2 * EXP_SCALED_ONE) / 3 + 1) as u128), 0);
        assert!(divide_up(10, 20) == ((EXP_SCALED_ONE / 2) as u128), 0);
        assert!(divide_up(10, 25) == (((2 * EXP_SCALED_ONE) / 5) as u128), 0);

        // Set 3
        assert!(divide_up(1, (EXP_SCALED_ONE as u128) + 1) == 1, 0);
        assert!(divide_up(1, (EXP_SCALED_ONE as u128)) == 1, 0);
        assert!(divide_up(1, (EXP_SCALED_ONE as u128) - 1) == 2, 0);
        assert!(divide_up(1, ((EXP_SCALED_ONE / 2) as u128) + 1) == 2, 0);
        assert!(divide_up(1, ((EXP_SCALED_ONE / 2) as u128)) == 2, 0);
        assert!(divide_up(1, ((EXP_SCALED_ONE / 2) as u128) - 1) == 3, 0);
    }

    #[test]
    fun test_multiply_down() {
        // Set 1a
        assert!(multiply_down(0, 1) == 0, 0);
        assert!(multiply_down((EXP_SCALED_ONE as u128), 1) == (1 as u256), 0);
        assert!(multiply_down((2 * EXP_SCALED_ONE as u128), 1) == (2 as u256), 0);
        assert!(multiply_down((3 * EXP_SCALED_ONE as u128), 1) == (3 as u256), 0);

        // Set 1b
        assert!(multiply_down((EXP_SCALED_ONE as u128), 1) == (1 as u256), 0);
        assert!(multiply_down(((EXP_SCALED_ONE / 2) as u128), 2) == (1 as u256), 0);
        assert!(multiply_down(((EXP_SCALED_ONE / 3) as u128), 3) == 0, 0);
        assert!(multiply_down(((EXP_SCALED_ONE / 3) as u128) + 1, 3) == (1 as u256), 0);

        // Set 2a
        assert!(multiply_down(0, 10) == 0, 0);
        assert!(multiply_down(((EXP_SCALED_ONE / 2) as u128), 10) == (5 as u256), 0);
        assert!(multiply_down((EXP_SCALED_ONE as u128), 10) == (10 as u256), 0);
        assert!(multiply_down(((EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 10) == (15 as u256), 0);
        assert!(multiply_down((2 * EXP_SCALED_ONE as u128), 10) == (20 as u256), 0);
        assert!(multiply_down(((2 * EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 10) == (25 as u256), 0);

        // Set 2b
        assert!(multiply_down((2 * EXP_SCALED_ONE as u128), 5) == (10 as u256), 0);
        assert!(multiply_down((EXP_SCALED_ONE as u128), 10) == (10 as u256), 0);
        assert!(multiply_down(((2 * EXP_SCALED_ONE / 3) as u128), 15) == (9 as u256), 0);
        assert!(multiply_down(((2 * EXP_SCALED_ONE / 3) as u128) + 1, 15) == (10 as u256), 0);
        assert!(multiply_down(((EXP_SCALED_ONE / 2) as u128), 20) == (10 as u256), 0);
        assert!(multiply_down(((2 * EXP_SCALED_ONE / 5) as u128), 25) == (10 as u256), 0);

        // Set 3
        assert!(multiply_down(1, (EXP_SCALED_ONE as u128) + 1) == (1 as u256), 0);
        assert!(multiply_down(1, (EXP_SCALED_ONE as u128)) == (1 as u256), 0);
        assert!(multiply_down(1, (EXP_SCALED_ONE as u128) - 1) == 0, 0);
        assert!(multiply_down(1, ((EXP_SCALED_ONE / 2) as u128) + 1) == 0, 0);
        assert!(multiply_down(2, ((EXP_SCALED_ONE / 2) as u128)) == (1 as u256), 0);
        assert!(multiply_down(2, ((EXP_SCALED_ONE / 2) as u128) - 1) == 0, 0);
    }

    #[test]
    fun test_multiply_up() {
        // Set 1a
        assert!(multiply_up(0, 1) == 0, 0);
        assert!(multiply_up((EXP_SCALED_ONE as u128), 1) == (1 as u256), 0);
        assert!(multiply_up((2 * EXP_SCALED_ONE as u128), 1) == (2 as u256), 0);
        assert!(multiply_up((3 * EXP_SCALED_ONE as u128), 1) == (3 as u256), 0);

        // Set 1b
        assert!(multiply_up((EXP_SCALED_ONE as u128), 1) == (1 as u256), 0);
        assert!(multiply_up(((EXP_SCALED_ONE / 2) as u128), 2) == (1 as u256), 0);
        assert!(multiply_up(((EXP_SCALED_ONE / 3) as u128), 3) == (1 as u256), 0);
        assert!(multiply_up(((EXP_SCALED_ONE / 3) as u128) + 1, 3) == (2 as u256), 0);

        // Set 2a
        assert!(multiply_up(0, 10) == 0, 0);
        assert!(multiply_up(((EXP_SCALED_ONE / 2) as u128), 10) == (5 as u256), 0);
        assert!(multiply_up((EXP_SCALED_ONE as u128), 10) == (10 as u256), 0);
        assert!(multiply_up(((EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 10) == (15 as u256), 0);
        assert!(multiply_up((2 * EXP_SCALED_ONE as u128), 10) == (20 as u256), 0);
        assert!(multiply_up(((2 * EXP_SCALED_ONE + EXP_SCALED_ONE / 2) as u128), 10) == (25 as u256), 0);

        // Set 2b
        assert!(multiply_up((2 * EXP_SCALED_ONE as u128), 5) == (10 as u256), 0);
        assert!(multiply_up((EXP_SCALED_ONE as u128), 10) == (10 as u256), 0);
        assert!(multiply_up(((2 * EXP_SCALED_ONE / 3) as u128), 15) == (10 as u256), 0);
        assert!(multiply_up(((2 * EXP_SCALED_ONE / 3) as u128) + 1, 15) == (11 as u256), 0);
        assert!(multiply_up(((EXP_SCALED_ONE / 2) as u128), 20) == (10 as u256), 0);
        assert!(multiply_up(((2 * EXP_SCALED_ONE / 5) as u128), 25) == (10 as u256), 0);

        // Set 3
        assert!(multiply_up(1, (EXP_SCALED_ONE as u128) + 1) == (2 as u256), 0);
        assert!(multiply_up(1, (EXP_SCALED_ONE as u128)) == (1 as u256), 0);
        assert!(multiply_up(1, (EXP_SCALED_ONE as u128) - 1) == (1 as u256), 0);
        assert!(multiply_up(1, ((EXP_SCALED_ONE / 2) as u128) + 1) == (1 as u256), 0);
        assert!(multiply_up(2, ((EXP_SCALED_ONE / 2) as u128)) == (1 as u256), 0);
        assert!(multiply_up(2, ((EXP_SCALED_ONE / 2) as u128) - 1) == (1 as u256), 0);
    }

    #[test]
    fun test_exponent() {
        assert!(exponent(0) == 1_000000000000, 0);
        
        assert!(exponent((EXP_SCALED_ONE / 10000) as u128) == 1_000100005000, 0);
        assert!(exponent((EXP_SCALED_ONE / 1000) as u128) == 1_001000500166, 0);
        assert!(exponent((EXP_SCALED_ONE / 100) as u128) == 1_010050167084, 0);
        assert!(exponent((EXP_SCALED_ONE / 10) as u128) == 1_105170918075, 0);
        assert!(exponent((EXP_SCALED_ONE / 2) as u128) == 1_648721270572, 0);
        assert!(exponent(EXP_SCALED_ONE as u128) == 2_718281718281, 0);
        assert!(exponent((EXP_SCALED_ONE * 2) as u128) == 7_388888888888, 0);
        
        // Demonstrate maximum of ~200e12
        assert!(exponent((EXP_SCALED_ONE * 5) as u128) == 128_619047619047, 0);
        assert!(exponent((EXP_SCALED_ONE * 6) as u128) == 196_000000000000, 0);
        assert!(exponent((EXP_SCALED_ONE * 7) as u128) == 159_260869565217, 0);
    }

    #[test]
    fun test_get_continuous_index() {
        assert!(get_continuous_index(EXP_SCALED_ONE, 0) == 1_000000000000, 0);
        assert!(get_continuous_index(EXP_SCALED_ONE, 86400) == 1_002743482506, 0); // 1 day
        assert!(get_continuous_index(EXP_SCALED_ONE, 864000) == 1_027776016255, 0); // 10 days
        assert!(get_continuous_index(EXP_SCALED_ONE, 31536000) == 2718281718281, 0); // 365 days
    }

    #[test]
    fun test_convert_to_basis_points() {
        assert!(convert_to_basis_points(1_000000000000) == 10_000, 0);
        assert!(convert_to_basis_points(18446744073709551615) == 184467440_737, 0); // max u64
    }

    #[test]
    fun test_convert_from_basis_points() {
        assert!(convert_from_basis_points(10_000) == 1_000000000000, 0);
        assert!(convert_from_basis_points(4294967295) == 429496_729500000000, 0); // max u32
    }

    #[test]
    fun test_exponent_limits() {
        let x: u128 = 6_101171897009;
        let max_exponent: u64 = 196_691035579298;

        assert!(exponent(x) == max_exponent, 0);

        // Test values around the max
        assert!(exponent(x - 1) <= max_exponent, 0);
        assert!(exponent(x - 10) <= max_exponent, 0);
        assert!(exponent(x - 100) <= max_exponent, 0);
        assert!(exponent(x - 1000) <= max_exponent, 0);

        assert!(exponent(x + 1) <= max_exponent, 0);
        assert!(exponent(x + 10) <= max_exponent, 0);
        assert!(exponent(x + 100) <= max_exponent, 0);
        assert!(exponent(x + 1000) <= max_exponent, 0);
    }

    #[test]
    fun test_multiply_then_divide_100apy() {
        let amount: u128 = 1_000_000_000; // 1000e6
        let seven_day_rate = get_continuous_index(EXP_SCALED_ONE, 604800) as u128; // 7 days
        let thirty_day_rate = get_continuous_index(EXP_SCALED_ONE, 2592000) as u128; // 30 days
        
        let multiplied = multiply_down(amount, seven_day_rate);
        let divided = divide_down(multiplied, seven_day_rate);
        assert!(divided == amount - 1 || divided == amount, 0);
        
        let divided_first = divide_down(amount as u256, seven_day_rate);
        let multiplied_after = multiply_down(divided_first, seven_day_rate);
        assert!(multiplied_after == (amount as u256) - 1 || multiplied_after == (amount as u256), 0);
        
        let multiplied_30 = multiply_down(amount, thirty_day_rate);
        let divided_30 = divide_down(multiplied_30, thirty_day_rate);
        assert!(divided_30 == amount - 1 || divided_30 == amount, 0);
        
        let divided_first_30 = divide_down(amount as u256, thirty_day_rate);
        let multiplied_after_30 = multiply_down(divided_first_30, thirty_day_rate);
        assert!(multiplied_after_30 == (amount as u256) - 1 || multiplied_after_30 == (amount as u256), 0);
    }

    #[test]
    fun test_multiply_then_divide_6apy() {
        let amount: u128 = 1_000_000_000; // 1000e6
        let seven_day_rate = get_continuous_index((EXP_SCALED_ONE * 6) / 100, 604800) as u128; // 7 days
        let thirty_day_rate = get_continuous_index((EXP_SCALED_ONE * 6) / 100, 2592000) as u128; // 30 days
        
        let multiplied = multiply_down(amount, seven_day_rate);
        let divided = divide_down(multiplied, seven_day_rate);
        assert!(divided == amount - 1 || divided == amount, 0);
        
        let divided_first = divide_down(amount as u256, seven_day_rate);
        let multiplied_after = multiply_down(divided_first, seven_day_rate);
        assert!(multiplied_after == (amount as u256) - 1 || multiplied_after == (amount as u256), 0);
        
        let multiplied_30 = multiply_down(amount, thirty_day_rate);
        let divided_30 = divide_down(multiplied_30, thirty_day_rate);
        assert!(divided_30 == amount - 1 || divided_30 == amount, 0);
        
        let divided_first_30 = divide_down(amount as u256, thirty_day_rate);
        let multiplied_after_30 = multiply_down(divided_first_30, thirty_day_rate);
        assert!(multiplied_after_30 == (amount as u256) - 1 || multiplied_after_30 == (amount as u256), 0);
    }

    #[test]
    #[expected_failure]
    fun test_divide_by_zero() {
        divide_down(100, 0);
    }

    #[test]
    #[expected_failure]
    fun test_divide_up_by_zero() {
        divide_up(100, 0);
    }
}