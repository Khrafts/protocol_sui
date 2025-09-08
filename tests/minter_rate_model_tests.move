#[test_only]
module protocol_sui::minter_rate_model_tests {
    use protocol_sui::minter_rate_model;
    use protocol_sui::ttg_registrar::{Self, TTGRegistrar};
    use protocol_sui::uint_math;
    use sui::test_scenario;
    
    // ============ Test Constants ============
    
    const TEST_SENDER: address = @0x1;
    
    // ============ Test Functions ============
    
    #[test]
    fun test_max_minter_rate_enforcement() {
        // Test that the minter rate is capped at MAX_MINTER_RATE (40,000 basis points)
        // Using uint_math::min256 directly to test the pure logic
        
        // Test with rate above maximum
        let base_minter_rate = 100_000; // 1000% in basis points
        let rate = uint_math::min256(base_minter_rate, 40_000);
        assert!(rate == 40_000, 0); // Should be capped at 40,000
        
        // Test with rate at maximum
        let base_minter_rate = 40_000; // 400% in basis points
        let rate = uint_math::min256(base_minter_rate, 40_000);
        assert!(rate == 40_000, 1);
        
        // Test with rate below maximum
        let base_minter_rate = 20_000; // 200% in basis points
        let rate = uint_math::min256(base_minter_rate, 40_000);
        assert!(rate == 20_000, 2);
        
        // Test with zero rate
        let base_minter_rate = 0;
        let rate = uint_math::min256(base_minter_rate, 40_000);
        assert!(rate == 0, 3);
        
        // Test with small rate
        let base_minter_rate = 500; // 5% in basis points
        let rate = uint_math::min256(base_minter_rate, 40_000);
        assert!(rate == 500, 4);
    }
    
    #[test]
    fun test_rate_with_ttg_registrar() {
        let mut scenario = test_scenario::begin(TEST_SENDER);
        
        // Initialize TTGRegistrar
        {
            ttg_registrar::initialize(test_scenario::ctx(&mut scenario));
        };
        
        // Test with default rate
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let registrar = test_scenario::take_shared<TTGRegistrar>(&scenario);
            
            // Default base minter rate should be 500 (5%)
            let rate = minter_rate_model::rate(&registrar);
            assert!(rate == 500, 0);
            
            test_scenario::return_shared(registrar);
        };
        
        // Test with updated rate below maximum
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let mut registrar = test_scenario::take_shared<TTGRegistrar>(&scenario);
            
            // Set base minter rate to 25% (2500 basis points)
            ttg_registrar::set_base_minter_rate(&mut registrar, 2500);
            
            let rate = minter_rate_model::rate(&registrar);
            assert!(rate == 2500, 1);
            
            test_scenario::return_shared(registrar);
        };
        
        // Test with updated rate above maximum
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let mut registrar = test_scenario::take_shared<TTGRegistrar>(&scenario);
            
            // Set base minter rate to 1000% (100,000 basis points)
            ttg_registrar::set_base_minter_rate(&mut registrar, 100_000);
            
            let rate = minter_rate_model::rate(&registrar);
            assert!(rate == 40_000, 2); // Should be capped at MAX_MINTER_RATE
            
            test_scenario::return_shared(registrar);
        };
        
        // Test with rate exactly at maximum
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let mut registrar = test_scenario::take_shared<TTGRegistrar>(&scenario);
            
            // Set base minter rate to 400% (40,000 basis points)
            ttg_registrar::set_base_minter_rate(&mut registrar, 40_000);
            
            let rate = minter_rate_model::rate(&registrar);
            assert!(rate == 40_000, 3);
            
            test_scenario::return_shared(registrar);
        };
        
        // Test with zero rate
        test_scenario::next_tx(&mut scenario, TEST_SENDER);
        {
            let mut registrar = test_scenario::take_shared<TTGRegistrar>(&scenario);
            
            // Set base minter rate to 0%
            ttg_registrar::set_base_minter_rate(&mut registrar, 0);
            
            let rate = minter_rate_model::rate(&registrar);
            assert!(rate == 0, 4);
            
            test_scenario::return_shared(registrar);
        };
        
        test_scenario::end(scenario);
    }
    
    #[test]
    fun test_max_rate_constant() {
        // Verify that max_rate() returns the expected constant value
        let max_rate = minter_rate_model::max_rate();
        assert!(max_rate == 40_000, 0); // 400% in basis points
    }
    
}